//
//  CloudKitPartnerStore.swift
//  blocking app
//
//  CloudKit wrapper for the Recovery Partner feature. Designed in
//  docs/PARTNER_FEATURE_DESIGN_AR.md (CloudKit + Apple ID, no custom backend).
//
//  Day-1 surface: account-status detection and the record-type / DTO definitions
//  that the rest of the feature (invitation, accept, break-attempt push) will
//  build on. The CKShare-based invitation flow lands in a follow-up commit.
//
//  Setup (one-time, outside this file):
//  1. Xcode → Signing & Capabilities → enable iCloud (CloudKit) and Push Notifications.
//  2. App Store Connect → CloudKit Dashboard → create container `iCloud.com.nonetapp`.
//  3. Schema is deployed lazily on first record save (or via the CloudKit Dashboard
//     editor before shipping to production).
//

import CloudKit
import Foundation
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "CloudKitPartner")

// MARK: - Local DTOs (mirror the CloudKit records, decoupled from CKRecord)

enum PartnershipStatus: String, Codable {
    case pending
    case accepted
    case rejected
    case revoked
}

struct Partnership: Identifiable, Hashable {
    let id: String                  // CKRecord.ID.recordName
    var ownerUserID: String
    var partnerUserID: String?
    var ownerDisplayName: String
    var partnerDisplayName: String?
    /// The nickname the inviter suggested for the partner at invite time —
    /// shown on the invitee's accept sheet as a starting point. The invitee
    /// can override it with their own preferred name before accepting.
    var proposedPartnerName: String?
    var status: PartnershipStatus
    var createdAt: Date
    var acceptedAt: Date?
    var associatedListIDs: [UUID]
    /// Which CloudKit database this Partnership (and its child BreakAttempts)
    /// lives in. Owner-created partnerships are in `.private`; partnerships
    /// the user accepted from someone else are in `.shared`. Captured at
    /// fetch time so subsequent operations don't have to try both DBs.
    var databaseScope: CKDatabase.Scope
}

enum BreakAttemptType: String, Codable {
    case disable
    case delete
    case modify
    case uninstallAttempt = "uninstall_attempt"
}

/// State machine for a BreakAttempt record. Distinguishes "request awaiting
/// partner decision" from "log of a refused break" — both fields share the
/// same CloudKit record type to keep the schema small.
enum RequestStatus: String, Codable {
    case pending      // sender created the request, awaiting partner decision
    case approved     // partner approved → action will execute
    case denied       // partner denied → action is blocked
    case completed    // action has executed after approval (delete/disable/modify)
    case cancelled    // sender withdrew the request before partner decided
    case logOnly      // legacy/observer mode — recorded, not actionable. Used
                      // by recordBreakAttempt(_:) calls that pre-date the
                      // approval workflow.
}

struct BreakAttempt: Identifiable, Hashable {
    let id: String                  // CKRecord.ID.recordName
    let partnershipID: String
    let listID: UUID
    let listName: String
    let attemptedAt: Date
    let type: BreakAttemptType
    let reachedThrough: String?
    /// Approval-workflow state. Defaults to .logOnly on records produced by
    /// the legacy recordBreakAttempt() path; new records from
    /// createActionRequest() start at .pending.
    var status: RequestStatus
    /// User-written explanation submitted with the request. Optional —
    /// some action types (like .modify) may not require one.
    var reason: String?
    /// When the partner approved / denied / the user cancelled. nil while
    /// status == .pending or .logOnly.
    var decidedAt: Date?
}

// MARK: - CloudKit record-type names (single source of truth)

enum PartnerRecordTypes {
    static let partnership = "Partnership"
    static let breakAttempt = "BreakAttempt"
    static let partnerProfile = "PartnerProfile"
}

@MainActor
final class CloudKitPartnerStore: ObservableObject {
    static let shared = CloudKitPartnerStore()

    /// Must match `com.apple.developer.icloud-container-identifiers` in entitlements
    /// and the container created in App Store Connect.
    static let containerID = "iCloud.com.nonetapp"

    let container: CKContainer
    let privateDB: CKDatabase
    let sharedDB: CKDatabase

    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published private(set) var partnerships: [Partnership] = []
    @Published private(set) var lastError: String?
    /// The current device's iCloud userRecordID.recordName. Populated lazily
    /// after `refreshAccountStatus()` succeeds. Required for owner/partner
    /// role detection (compare against `partnership.partnerUserID`).
    @Published private(set) var currentUserRecordID: String?
    /// BreakAttempt records the current device should review — i.e. requests
    /// addressed TO this device acting as a recovery partner. Populated by
    /// fetchPendingRequestsForMe and on every CloudKit push.
    @Published private(set) var pendingPartnerRequests: [BreakAttempt] = []
    /// BreakAttempt records the current device originated — used by HomeView
    /// to show a "pending partner approval" indicator on Hard+Partner lists.
    @Published private(set) var myOutgoingRequests: [BreakAttempt] = []
    /// A share invitation that just arrived via the Scene delegate but has
    /// not yet been accepted — ContentView observes this and presents
    /// PartnerAcceptSheet so the invitee can choose a display name first.
    @Published var pendingShareMetadata: CKShare.Metadata?

    private init() {
        self.container = CKContainer(identifier: Self.containerID)
        self.privateDB = container.privateCloudDatabase
        self.sharedDB = container.sharedCloudDatabase
    }

    /// Convenience: most call-sites only need "can we do CloudKit work right now?".
    var isAccountAvailable: Bool { accountStatus == .available }

    /// True iff the given partnership.partnerUserID is THIS device's userRecordID
    /// (i.e., the device viewing this partnership is the invitee, not the owner).
    /// Returns false when `currentUserRecordID` hasn't loaded yet, defaulting to
    /// owner-view rather than misclassifying.
    func isInvitee(_ partnership: Partnership) -> Bool {
        guard let myID = currentUserRecordID, let theirID = partnership.partnerUserID else { return false }
        return myID == theirID
    }

    /// Re-checks the user's iCloud account state. Call on app launch and on
    /// `CKAccountChanged` notifications. Idempotent. Also caches the user's
    /// own recordID once available so role detection (owner vs invitee) works.
    func refreshAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            self.accountStatus = status
            log.notice("iCloud accountStatus: \(self.describe(status), privacy: .public)")
            // Cache userRecordID for owner/invitee role detection. Only attempt
            // when account is healthy — the call would fail otherwise and the
            // failure isn't actionable for the user.
            if status == .available, currentUserRecordID == nil {
                do {
                    let recordID = try await container.userRecordID()
                    self.currentUserRecordID = recordID.recordName
                } catch {
                    log.error("userRecordID fetch failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        } catch {
            log.error("accountStatus check failed: \(error.localizedDescription, privacy: .public)")
            self.lastError = error.localizedDescription
        }
    }

    /// User-facing reason string for why CloudKit features aren't available right now.
    /// Returns nil when account is healthy. Localized via the passed-in flag because the
    /// store has no LanguageManager dependency.
    func accountUnavailableReason(isArabic: Bool) -> String? {
        switch accountStatus {
        case .available:
            return nil
        case .noAccount:
            return isArabic ? "يحتاج الشريك حساب iCloud مفعّلاً." : "iCloud account required for partner features."
        case .restricted:
            return isArabic ? "الوصول إلى iCloud مقيّد من قبل الجهاز." : "iCloud access is restricted on this device."
        case .couldNotDetermine:
            return isArabic ? "تعذّر التحقق من حالة iCloud." : "Could not determine iCloud account status."
        case .temporarilyUnavailable:
            return isArabic ? "iCloud غير متاح حالياً، حاول لاحقاً." : "iCloud is temporarily unavailable."
        @unknown default:
            return isArabic ? "حالة iCloud غير معروفة." : "Unknown iCloud account state."
        }
    }

    private func describe(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return "available"
        case .noAccount: return "noAccount"
        case .restricted: return "restricted"
        case .couldNotDetermine: return "couldNotDetermine"
        case .temporarilyUnavailable: return "temporarilyUnavailable"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Invitation (Inviter side)

    enum PartnerStoreError: LocalizedError {
        case accountUnavailable
        case noUserRecord

        var errorDescription: String? {
            switch self {
            case .accountUnavailable: return "iCloud account is not available."
            case .noUserRecord: return "Could not fetch the current iCloud user record."
            }
        }
    }

    /// Create a pending Partnership record + CKShare. The caller hands the returned
    /// CKShare to UICloudSharingController to deliver the invitation via Messages/Mail/etc.
    ///
    /// The record is saved in the user's private database; the CKShare moves it into a
    /// shared zone once the invitee accepts. associatedListIDs starts with the single list
    /// that triggered the invite — additional lists can be added later via fetch+update.
    ///
    /// `proposedPartnerName` is the nickname the inviter chose for the invitee at
    /// invite time ("Abu Mohammed", "Mom"). It's shown on the invitee's accept
    /// sheet as a starting point; the invitee can override it with their own
    /// preferred name before accepting.
    func createPartnership(ownerDisplayName: String, proposedPartnerName: String?, associatedListID: UUID) async throws -> (CKShare, CKRecord) {
        guard isAccountAvailable else { throw PartnerStoreError.accountUnavailable }

        let ownerID = try await container.userRecordID()

        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: PartnerRecordTypes.partnership, recordID: recordID)
        record["ownerUserID"] = ownerID.recordName as CKRecordValue
        record["ownerDisplayName"] = ownerDisplayName as CKRecordValue
        if let proposed = proposedPartnerName, !proposed.isEmpty {
            record["proposedPartnerName"] = proposed as CKRecordValue
        }
        record["status"] = PartnershipStatus.pending.rawValue as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["associatedListIDs"] = [associatedListID.uuidString] as CKRecordValue

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "Recovery Partner — \(ownerDisplayName)" as CKRecordValue
        share.publicPermission = .none

        try await save(records: [record, share])
        log.notice("createPartnership: saved \(recordID.recordName, privacy: .public) for list \(associatedListID, privacy: .public)")
        return (share, record)
    }

    /// Attach an additional list to an existing partnership — used when the
    /// user creates a new Hard Mode list and picks an already-accepted partner
    /// from the Partner step in CreateListSheet (Phase 2 of v1.3.0).
    ///
    /// Fetches the Partnership by recordName, appends the new list UUID to
    /// `associatedListIDs` (deduping in case of double-tap), and saves. The
    /// partnership lives in the owner's private DB once accepted; for the
    /// invitee side we look it up via sharedDatabase.
    func attachPartnership(_ partnerRecordName: String, toList listID: UUID) async {
        let recordID = CKRecord.ID(recordName: partnerRecordName)
        let listIDString = listID.uuidString
        do {
            // Try private DB first (the common case — most users are the owner
            // creating Hard Mode lists with their own pre-accepted partner).
            // Fall back to sharedDB for invitees attaching to a partnership
            // they accepted from someone else.
            var record: CKRecord
            do {
                record = try await privateDB.record(for: recordID)
            } catch {
                record = try await sharedDB.record(for: recordID)
            }
            var ids = (record["associatedListIDs"] as? [String]) ?? []
            if !ids.contains(listIDString) {
                ids.append(listIDString)
            }
            record["associatedListIDs"] = ids as CKRecordValue
            try await save(records: [record])
            log.notice("attachPartnership: list \(listIDString, privacy: .public) attached to \(partnerRecordName, privacy: .public)")
            // Refresh the local cache so the new association is reflected in
            // any view observing partnerships.
            await fetchPartnerships()
        } catch {
            log.error("attachPartnership failed for \(partnerRecordName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            self.lastError = error.localizedDescription
        }
    }

    /// Persist multiple records (record + share) in a single transaction.
    private func save(records: [CKRecord]) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .ifServerRecordUnchanged
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            self.privateDB.add(operation)
        }
    }

    // MARK: - Approval workflow (the gatekeeper part of Recovery Partner)

    /// Create a new action request (delete/disable/modify) addressed to a
    /// recovery partner. Saved as a BreakAttempt record with status=.pending;
    /// the partner gets a push via the CKQuerySubscription and responds with
    /// approveRequest / denyRequest.
    ///
    /// Returns the record's name so the caller can track it locally.
    @discardableResult
    func createActionRequest(partnershipID: String,
                             listID: UUID,
                             listName: String,
                             type: BreakAttemptType,
                             reason: String?) async -> String? {
        let attemptID = UUID()
        let attemptedAt = Date()

        // Offline-safety: an approval request is the *most* important kind of
        // BreakAttempt to land — the user is actively waiting for a partner
        // decision and the UI shows "request sent". Dropping it silently was
        // the original bug. Mirror the offline-aware path that recordBreakAttempt
        // already uses: queue locally if iCloud is unreachable, replay on the
        // next foreground / account-change event via flushPendingBreakAttempts.
        guard isAccountAvailable else {
            log.notice("createActionRequest: account unavailable, queuing locally")
            PendingBreakAttemptQueue.enqueue(PendingBreakAttempt(
                id: attemptID,
                partnershipID: partnershipID,
                listID: listID,
                listName: listName,
                attemptedAt: attemptedAt,
                typeRaw: type.rawValue,
                reachedThrough: "approval_request",
                statusRaw: RequestStatus.pending.rawValue,
                reason: reason
            ))
            return attemptID.uuidString
        }

        let record = makeBreakAttemptRecord(
            recordName: attemptID.uuidString,
            partnershipID: partnershipID,
            listID: listID,
            listName: listName,
            attemptedAt: attemptedAt,
            type: type,
            reachedThrough: "approval_request",
            status: .pending,
            reason: reason
        )
        do {
            try await save(records: [record])
            log.notice("createActionRequest: \(type.rawValue, privacy: .public) for list \(listID, privacy: .public)")
            await fetchMyOutgoingRequests()
            return attemptID.uuidString
        } catch {
            // Same enqueue-on-failure path as recordBreakAttempt. The user's
            // UI already committed to "request sent"; deferring the actual
            // CloudKit write keeps that promise once connectivity returns.
            log.error("createActionRequest failed, enqueuing: \(error.localizedDescription, privacy: .public)")
            PendingBreakAttemptQueue.enqueue(PendingBreakAttempt(
                id: attemptID,
                partnershipID: partnershipID,
                listID: listID,
                listName: listName,
                attemptedAt: attemptedAt,
                typeRaw: type.rawValue,
                reachedThrough: "approval_request",
                statusRaw: RequestStatus.pending.rawValue,
                reason: reason
            ))
            return attemptID.uuidString
        }
    }

    /// Partner's decision: approve. Updates the BreakAttempt's status so the
    /// requesting device sees the decision on next push / fetch.
    func approveRequest(_ requestID: String) async {
        await updateRequestStatus(requestID: requestID, to: .approved)
    }

    /// Partner's decision: deny. Same as approveRequest but with .denied.
    func denyRequest(_ requestID: String) async {
        await updateRequestStatus(requestID: requestID, to: .denied)
    }

    /// Sender cancels their own pending request before the partner decides.
    func cancelMyRequest(_ requestID: String) async {
        await updateRequestStatus(requestID: requestID, to: .cancelled)
    }

    /// Mark a request as completed once the local action (e.g. delete) has
    /// actually run. Called by AppDelegate's push handler after executing.
    func markRequestCompleted(_ requestID: String) async {
        await updateRequestStatus(requestID: requestID, to: .completed)
    }

    private func updateRequestStatus(requestID: String, to status: RequestStatus) async {
        let recordID = CKRecord.ID(recordName: requestID)

        // Resolve the preferred DB from cached state. The BreakAttempt's
        // parent partnership knows its scope (set at fetch time), so we
        // can route fetch + save to the right database directly instead
        // of probing both. If the caches are cold (rare), fall back to
        // the legacy try-shared-then-private order.
        let cachedAttempt = myOutgoingRequests.first(where: { $0.id == requestID })
            ?? pendingPartnerRequests.first(where: { $0.id == requestID })
        let cachedPartnership = cachedAttempt.flatMap { attempt in
            partnerships.first(where: { $0.id == attempt.partnershipID })
        }
        let dbOrder: [CKDatabase]
        if let partnership = cachedPartnership {
            let preferred = database(for: partnership)
            let other: CKDatabase = (preferred === sharedDB) ? privateDB : sharedDB
            dbOrder = [preferred, other]
        } else {
            dbOrder = [sharedDB, privateDB]
        }

        var record: CKRecord?
        var foundIn: CKDatabase?
        for db in dbOrder {
            if let r = try? await db.record(for: recordID) {
                record = r
                foundIn = db
                break
            }
        }
        guard let record = record, let foundIn = foundIn else {
            log.error("updateRequestStatus: record \(requestID, privacy: .public) not found")
            return
        }
        record["status"] = status.rawValue as CKRecordValue
        record["decidedAt"] = Date() as CKRecordValue
        do {
            _ = try await foundIn.save(record)
            log.notice("updateRequestStatus: \(requestID, privacy: .public) → \(status.rawValue, privacy: .public)")
            await fetchPendingRequestsForMe()
            await fetchMyOutgoingRequests()
        } catch {
            log.error("updateRequestStatus save in \(foundIn.databaseScope.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetch break-attempt records addressed TO this device (i.e. ones where
    /// the user acts as the recovery partner, not the sender). Populates
    /// `pendingPartnerRequests` so HomeView can render approval banners.
    ///
    /// Filtering is done post-fetch by cross-referencing each record's
    /// partnershipID against the cached `partnerships` array — the user is
    /// the partner iff `partnership.partnerUserID == currentUserRecordID`.
    /// Without this, the sender would see their own pending requests as
    /// "approve/deny" prompts on their own device.
    func fetchPendingRequestsForMe() async {
        let query = CKQuery(
            recordType: PartnerRecordTypes.breakAttempt,
            predicate: NSPredicate(format: "status == %@", RequestStatus.pending.rawValue)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "attemptedAt", ascending: false)]
        do {
            let (results, _) = try await sharedDB.records(matching: query)
            let attempts = results.compactMap { _, result -> BreakAttempt? in
                guard case .success(let record) = result else { return nil }
                return BreakAttempt(from: record)
            }
            self.pendingPartnerRequests = attempts.filter { isIncoming($0) }
        } catch {
            log.error("fetchPendingRequestsForMe failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetch break-attempt records the current device originated (i.e. the
    /// user is the owner in the partnership). Populates `myOutgoingRequests`
    /// so HomeView can show "Awaiting partner" badges + a cancel action.
    func fetchMyOutgoingRequests() async {
        let query = CKQuery(
            recordType: PartnerRecordTypes.breakAttempt,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "attemptedAt", ascending: false)]
        var collected: [BreakAttempt] = []
        for db in [privateDB, sharedDB] {
            do {
                let (results, _) = try await db.records(matching: query)
                let attempts = results.compactMap { _, result -> BreakAttempt? in
                    guard case .success(let record) = result else { return nil }
                    return BreakAttempt(from: record)
                }
                collected.append(contentsOf: attempts)
            } catch {
                log.error("fetchMyOutgoingRequests in \(db.databaseScope.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        self.myOutgoingRequests = collected
            .filter { isOutgoing($0) }
            .filter { $0.status == .pending || $0.status == .approved || $0.status == .denied }
    }

    /// True if the BreakAttempt was sent TO this device (we're the partner).
    /// False otherwise (we're the sender, or we have no partnership context).
    private func isIncoming(_ request: BreakAttempt) -> Bool {
        guard let myID = currentUserRecordID else { return false }
        guard let p = partnerships.first(where: { $0.id == request.partnershipID }) else {
            return false
        }
        return p.partnerUserID == myID
    }

    /// True if this device originated the BreakAttempt (we're the sender,
    /// i.e. the partnership owner). Opposite of isIncoming for sane records.
    private func isOutgoing(_ request: BreakAttempt) -> Bool {
        guard let myID = currentUserRecordID else { return false }
        guard let p = partnerships.first(where: { $0.id == request.partnershipID }) else {
            return false
        }
        return p.ownerUserID == myID
    }

    // MARK: - Break attempts (legacy log-only path)

    /// Log a break-attempt to CloudKit. The partner gets a push via the CKQuerySubscription
    /// the partnership owner sets up on first save.
    ///
    /// Persistence guarantee: if iCloud is unavailable (account, network, or transient
    /// CKError), the attempt is enqueued locally to `PendingBreakAttemptQueue` and
    /// replayed by `flushPendingBreakAttempts()` on the next account/foreground
    /// transition. The user-facing "you can't break Hard Mode" experience never
    /// waits on this, but the partner notification is no longer best-effort.
    func recordBreakAttempt(partnershipID: String,
                            listID: UUID,
                            listName: String,
                            type: BreakAttemptType,
                            reachedThrough: String? = nil) async {
        let attemptedAt = Date()
        let attemptID = UUID()

        // Fast path: account known offline — go straight to the queue without
        // round-tripping CloudKit.
        guard isAccountAvailable else {
            log.notice("recordBreakAttempt: account unavailable, queuing locally")
            PendingBreakAttemptQueue.enqueue(PendingBreakAttempt(
                id: attemptID,
                partnershipID: partnershipID,
                listID: listID,
                listName: listName,
                attemptedAt: attemptedAt,
                typeRaw: type.rawValue,
                reachedThrough: reachedThrough,
                statusRaw: nil,    // .logOnly path
                reason: nil
            ))
            return
        }

        let record = makeBreakAttemptRecord(
            recordName: attemptID.uuidString,
            partnershipID: partnershipID,
            listID: listID,
            listName: listName,
            attemptedAt: attemptedAt,
            type: type,
            reachedThrough: reachedThrough
        )

        do {
            try await save(records: [record])
            log.notice("recordBreakAttempt: \(type.rawValue, privacy: .public) on list \(listID, privacy: .public)")
        } catch {
            // CloudKit gave us an error mid-flight. Persist locally and let the
            // next flush retry — the partner will still get the push, just later.
            log.error("recordBreakAttempt failed, enqueuing: \(error.localizedDescription, privacy: .public)")
            PendingBreakAttemptQueue.enqueue(PendingBreakAttempt(
                id: attemptID,
                partnershipID: partnershipID,
                listID: listID,
                listName: listName,
                attemptedAt: attemptedAt,
                typeRaw: type.rawValue,
                reachedThrough: reachedThrough,
                statusRaw: nil,    // .logOnly path
                reason: nil
            ))
        }
    }

    /// Replay any queued BreakAttempts. Safe to call repeatedly — entries that
    /// succeed are removed individually, so partial flush is fine.
    ///
    /// Wired into:
    ///   * `ContentView.onAppear` / `CKAccountChanged` listener
    ///   * After every `fetchPartnerships()` success.
    func flushPendingBreakAttempts() async {
        let pending = PendingBreakAttemptQueue.load()
        guard !pending.isEmpty else { return }
        guard isAccountAvailable else {
            log.notice("flushPendingBreakAttempts: account still unavailable, deferring \(pending.count) entries")
            return
        }

        log.notice("flushPendingBreakAttempts: \(pending.count) entries to replay")
        var didFlushAnyApproval = false
        for attempt in pending {
            // Replay with the original status / reason so approval requests
            // come out the other side as .pending (not .logOnly) — otherwise
            // a deferred approval request would land as a log entry and the
            // partner would never see the approve/deny prompt.
            let record = makeBreakAttemptRecord(
                recordName: attempt.id.uuidString,
                partnershipID: attempt.partnershipID,
                listID: attempt.listID,
                listName: attempt.listName,
                attemptedAt: attempt.attemptedAt,
                type: attempt.type,
                reachedThrough: attempt.reachedThrough,
                status: attempt.status,
                reason: attempt.reason
            )
            do {
                try await save(records: [record])
                PendingBreakAttemptQueue.remove(id: attempt.id)
                log.notice("flushed pending attempt \(attempt.id, privacy: .public) (status=\(attempt.status.rawValue, privacy: .public))")
                if attempt.status == .pending { didFlushAnyApproval = true }
            } catch {
                // Stop on first persistent failure; we'll try the rest next
                // time the trigger fires. Avoids hammering CloudKit if iCloud
                // is mid-degradation.
                log.error("flush stalled on attempt \(attempt.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        // Refresh the outgoing-requests cache so HomeView's "awaiting partner"
        // badge correctly reflects the now-uploaded approval requests.
        if didFlushAnyApproval {
            await fetchMyOutgoingRequests()
        }
    }

    /// Build a BreakAttempt CKRecord. Extracted so the live-write path and the
    /// queue-flush path produce identical records.
    ///
    /// Default values (status: .logOnly, reason: nil) preserve the legacy
    /// "fire and forget" semantics of recordBreakAttempt — the approval
    /// workflow path (createActionRequest) passes status: .pending + reason.
    private func makeBreakAttemptRecord(recordName: String,
                                        partnershipID: String,
                                        listID: UUID,
                                        listName: String,
                                        attemptedAt: Date,
                                        type: BreakAttemptType,
                                        reachedThrough: String?,
                                        status: RequestStatus = .logOnly,
                                        reason: String? = nil) -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: PartnerRecordTypes.breakAttempt, recordID: recordID)
        let partnershipRecordID = CKRecord.ID(recordName: partnershipID)
        record["partnershipID"] = CKRecord.Reference(recordID: partnershipRecordID, action: .deleteSelf)
        record["listID"] = listID.uuidString as CKRecordValue
        record["listName"] = listName as CKRecordValue
        record["attemptedAt"] = attemptedAt as CKRecordValue
        record["attemptType"] = type.rawValue as CKRecordValue
        record["status"] = status.rawValue as CKRecordValue
        if let r = reachedThrough { record["reachedThrough"] = r as CKRecordValue }
        if let r = reason, !r.isEmpty { record["reason"] = r as CKRecordValue }
        return record
    }

    /// Fetch all break attempts for a given partnership, newest first.
    /// Routes to the partnership's known database when possible (the common
    /// case — caller fetched partnerships before this call), and falls back
    /// to querying both DBs only when the partnership isn't in the local
    /// cache (cold-start, race against fetchPartnerships).
    func fetchBreakAttempts(partnershipID: String) async -> [BreakAttempt] {
        let partnershipRecordID = CKRecord.ID(recordName: partnershipID)
        let ref = CKRecord.Reference(recordID: partnershipRecordID, action: .none)
        let query = CKQuery(
            recordType: PartnerRecordTypes.breakAttempt,
            predicate: NSPredicate(format: "partnershipID == %@", ref)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "attemptedAt", ascending: false)]

        let databasesToQuery: [CKDatabase] = {
            if let cached = partnerships.first(where: { $0.id == partnershipID }) {
                return [database(for: cached)]
            }
            return [privateDB, sharedDB]
        }()

        var attempts: [BreakAttempt] = []
        for db in databasesToQuery {
            do {
                let (results, _) = try await db.records(matching: query)
                let parsed = results.compactMap { _, result -> BreakAttempt? in
                    guard case .success(let record) = result else { return nil }
                    return BreakAttempt(from: record)
                }
                attempts.append(contentsOf: parsed)
            } catch {
                log.error("fetchBreakAttempts in \(db.databaseScope.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return attempts.sorted { $0.attemptedAt > $1.attemptedAt }
    }

    /// Returns the first partnership that has the given list in its associatedListIDs,
    /// or nil if none. Used to look up "is this list watched by a partner?" before
    /// recording a break attempt.
    func partnership(for listID: UUID) -> Partnership? {
        partnerships.first { $0.associatedListIDs.contains(listID) }
    }

    /// Delete a Partnership record. If we have the partnership cached, we
    /// know which DB owns it (databaseScope captured at fetch time) and go
    /// straight there. Otherwise fall back to the classic private-then-shared
    /// trial — happens when revoke is called against an id that hasn't been
    /// loaded into the local cache yet.
    func revokePartnership(id: String) async {
        let recordID = CKRecord.ID(recordName: id)
        if let partnership = partnerships.first(where: { $0.id == id }) {
            let db = database(for: partnership)
            do {
                _ = try await db.deleteRecord(withID: recordID)
            } catch {
                log.error("revokePartnership in \(db.databaseScope.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                self.lastError = error.localizedDescription
            }
        } else {
            // No cached scope — fall back to the old try-private-then-shared
            // path so a revoke from an old code path / cold-cache case still
            // works.
            do {
                _ = try await privateDB.deleteRecord(withID: recordID)
            } catch {
                do { _ = try await sharedDB.deleteRecord(withID: recordID) }
                catch {
                    log.error("revokePartnership fallback failed: \(error.localizedDescription, privacy: .public)")
                    self.lastError = error.localizedDescription
                }
            }
        }
        await fetchPartnerships()
    }

    // MARK: - Push subscriptions

    /// Register CKQuerySubscriptions so iOS pushes silent notifications when:
    ///   • A new BreakAttempt is created (partner is notified of a request)
    ///   • An existing BreakAttempt's status changes (sender is notified when
    ///     the partner approves/denies, and gets a content-available push so
    ///     ApprovalExecutor can act in the background).
    /// Both are best-effort and idempotent — re-running no-ops once installed.
    func setupSubscriptions() async {
        await installSubscription(
            id: "v1.breakAttempt.notify",
            options: [.firesOnRecordCreation],
            titleLocalizationKey: "PARTNER_BREAK_TITLE",
            alertLocalizationKey: "PARTNER_BREAK_BODY"
        )
        // Update push — silent (content-available only). The sender's device
        // wakes up just long enough for ApprovalExecutor to run.
        await installSubscription(
            id: "v1.breakAttempt.statusChange",
            options: [.firesOnRecordUpdate],
            titleLocalizationKey: nil,
            alertLocalizationKey: nil
        )
    }

    private func installSubscription(id subID: String,
                                     options: CKQuerySubscription.Options,
                                     titleLocalizationKey: String?,
                                     alertLocalizationKey: String?) async {
        let subscription = CKQuerySubscription(
            recordType: PartnerRecordTypes.breakAttempt,
            predicate: NSPredicate(value: true),
            subscriptionID: subID,
            options: options
        )
        let info = CKSubscription.NotificationInfo()
        if let titleKey = titleLocalizationKey {
            info.titleLocalizationKey = titleKey
        }
        if let alertKey = alertLocalizationKey {
            info.alertLocalizationKey = alertKey
            info.alertLocalizationArgs = ["listName"]
        }
        info.shouldSendContentAvailable = true
        // Only play sound for the "new request" push; status-change pushes
        // are silent so the sender doesn't get pinged twice for the same flow.
        if titleLocalizationKey != nil {
            info.soundName = "default"
        }
        subscription.notificationInfo = info

        do {
            _ = try await sharedDB.save(subscription)
            log.notice("subscription \(subID, privacy: .public) installed")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            log.notice("subscription \(subID, privacy: .public) already present")
        } catch {
            log.error("subscription \(subID, privacy: .public) install failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Invitee side

    /// Accept a share whose metadata was delivered via
    /// `windowScene(_:userDidAcceptCloudKitShareWith:)`. Apple completes the
    /// cross-account hand-off; after this resolves, the shared records become
    /// visible via `sharedDB`.
    ///
    /// `partnerDisplayName` is what the invitee wants to show as their name
    /// to the sender (defaulting to the inviter's proposedPartnerName if
    /// the invitee left it unchanged). Saving here means HomeView on the
    /// sender's device stops saying "Waiting for partner…" the moment the
    /// share lands.
    ///
    /// Returns the failure reason for display in PartnerAcceptSheet, or nil
    /// on success. The caller checks this rather than reading `lastError`
    /// (which may already be populated from an earlier, unrelated failure).
    @discardableResult
    func acceptInvitation(metadata: CKShare.Metadata, partnerDisplayName: String) async -> String? {
        do {
            _ = try await container.accept(metadata)
            log.notice("accepted share \(metadata.share.recordID.recordName, privacy: .public)")
            await fetchPartnerships()
            await markPartnershipAccepted(
                rootRecordID: metadata.hierarchicalRootRecordID,
                partnerDisplayName: partnerDisplayName
            )
            return nil
        } catch {
            log.error("accept share failed: \(error.localizedDescription, privacy: .public)")
            self.lastError = error.localizedDescription
            return error.localizedDescription
        }
    }

    /// Update the shared Partnership's status to accepted, stamp acceptedAt,
    /// and persist the partner's chosen display name.
    private func markPartnershipAccepted(rootRecordID: CKRecord.ID?, partnerDisplayName: String) async {
        guard let recordID = rootRecordID else { return }
        do {
            let record = try await sharedDB.record(for: recordID)
            record["status"] = PartnershipStatus.accepted.rawValue as CKRecordValue
            record["acceptedAt"] = Date() as CKRecordValue
            let partnerUserID = try await container.userRecordID().recordName
            record["partnerUserID"] = partnerUserID as CKRecordValue
            let trimmed = partnerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                record["partnerDisplayName"] = trimmed as CKRecordValue
            }
            _ = try await sharedDB.save(record)
            await fetchPartnerships()
        } catch {
            log.error("markPartnershipAccepted failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Reject a pending invitation. Called from PartnerAcceptSheet when the
    /// invitee taps "Reject" — updates the shared Partnership.status so the
    /// sender's UI reflects the rejection rather than hanging on "Waiting".
    ///
    /// Returns nil on success, or a localized error description for surfacing
    /// in the sheet. We need to accept the share first so CloudKit puts the
    /// record in our scope (no public decline API exists), then immediately
    /// stamp it as rejected.
    @discardableResult
    func rejectInvitation(metadata: CKShare.Metadata) async -> String? {
        guard let recordID = metadata.hierarchicalRootRecordID else {
            return "Missing share metadata"
        }
        do {
            _ = try? await container.accept(metadata)
            let record = try await sharedDB.record(for: recordID)
            record["status"] = PartnershipStatus.rejected.rawValue as CKRecordValue
            _ = try await sharedDB.save(record)
            log.notice("rejected share \(metadata.share.recordID.recordName, privacy: .public)")
            await fetchPartnerships()
            return nil
        } catch {
            log.error("rejectInvitation failed: \(error.localizedDescription, privacy: .public)")
            return error.localizedDescription
        }
    }

    /// Refresh `partnerships` from both the user's private DB (where they own the
    /// share) and the shared DB (where they've accepted someone else's share).
    func fetchPartnerships() async {
        var all: [Partnership] = []
        all.append(contentsOf: await fetchPartnerships(from: privateDB))
        all.append(contentsOf: await fetchPartnerships(from: sharedDB))
        self.partnerships = all
    }

    private func fetchPartnerships(from db: CKDatabase) async -> [Partnership] {
        let query = CKQuery(recordType: PartnerRecordTypes.partnership, predicate: NSPredicate(value: true))
        do {
            let (matchResults, _) = try await db.records(matching: query)
            return matchResults.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return Partnership(from: record, in: db.databaseScope)
            }
        } catch {
            log.error("fetchPartnerships from \(db.databaseScope.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Look up the CloudKit database that owns the given partnership's records.
    /// Falls back to `privateDB` if the partnership isn't cached — the common
    /// case for early callers is owner-side, so private is the safer default.
    func database(for partnership: Partnership) -> CKDatabase {
        switch partnership.databaseScope {
        case .public:  return container.publicCloudDatabase
        case .shared:  return sharedDB
        case .private: return privateDB
        @unknown default: return privateDB
        }
    }
}

// MARK: - Partnership <-> CKRecord bridging

extension Partnership {
    /// Build a Partnership DTO from a CKRecord. `scope` is captured at the
    /// fetch site (whichever DB the record was queried from) so operations
    /// on this partnership can route to the correct database without a
    /// trial-and-error double lookup.
    init?(from record: CKRecord, in scope: CKDatabase.Scope) {
        guard let ownerUserID = record["ownerUserID"] as? String,
              let ownerDisplayName = record["ownerDisplayName"] as? String,
              let statusRaw = record["status"] as? String,
              let status = PartnershipStatus(rawValue: statusRaw),
              let createdAt = record["createdAt"] as? Date else { return nil }
        self.id = record.recordID.recordName
        self.ownerUserID = ownerUserID
        self.partnerUserID = record["partnerUserID"] as? String
        self.ownerDisplayName = ownerDisplayName
        self.partnerDisplayName = record["partnerDisplayName"] as? String
        // Optional — older records (pre-PR2) don't have this field, that's OK.
        self.proposedPartnerName = record["proposedPartnerName"] as? String
        self.status = status
        self.createdAt = createdAt
        self.acceptedAt = record["acceptedAt"] as? Date
        let listIDStrings = (record["associatedListIDs"] as? [String]) ?? []
        self.associatedListIDs = listIDStrings.compactMap(UUID.init)
        self.databaseScope = scope
    }
}

extension BreakAttempt {
    init?(from record: CKRecord) {
        guard let ref = record["partnershipID"] as? CKRecord.Reference,
              let listIDStr = record["listID"] as? String,
              let listID = UUID(uuidString: listIDStr),
              let listName = record["listName"] as? String,
              let attemptedAt = record["attemptedAt"] as? Date,
              let typeRaw = record["attemptType"] as? String,
              let type = BreakAttemptType(rawValue: typeRaw) else { return nil }
        self.id = record.recordID.recordName
        self.partnershipID = ref.recordID.recordName
        self.listID = listID
        self.listName = listName
        self.attemptedAt = attemptedAt
        self.type = type
        self.reachedThrough = record["reachedThrough"] as? String
        // Older records (pre-PR2) won't have `status` — they predate the
        // approval workflow, so default to .logOnly which matches their
        // recordBreakAttempt origin.
        if let statusRaw = record["status"] as? String,
           let parsed = RequestStatus(rawValue: statusRaw) {
            self.status = parsed
        } else {
            self.status = .logOnly
        }
        self.reason = record["reason"] as? String
        self.decidedAt = record["decidedAt"] as? Date
    }
}
