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
    var status: PartnershipStatus
    var createdAt: Date
    var acceptedAt: Date?
    var associatedListIDs: [UUID]
}

enum BreakAttemptType: String, Codable {
    case disable
    case delete
    case modify
    case uninstallAttempt = "uninstall_attempt"
}

struct BreakAttempt: Identifiable, Hashable {
    let id: String                  // CKRecord.ID.recordName
    let partnershipID: String
    let listID: UUID
    let listName: String
    let attemptedAt: Date
    let type: BreakAttemptType
    let reachedThrough: String?
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

    private init() {
        self.container = CKContainer(identifier: Self.containerID)
        self.privateDB = container.privateCloudDatabase
        self.sharedDB = container.sharedCloudDatabase
    }

    /// Convenience: most call-sites only need "can we do CloudKit work right now?".
    var isAccountAvailable: Bool { accountStatus == .available }

    /// Re-checks the user's iCloud account state. Call on app launch and on
    /// `CKAccountChanged` notifications. Idempotent.
    func refreshAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            self.accountStatus = status
            log.notice("iCloud accountStatus: \(self.describe(status), privacy: .public)")
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
    func createPartnership(ownerDisplayName: String, associatedListID: UUID) async throws -> (CKShare, CKRecord) {
        guard isAccountAvailable else { throw PartnerStoreError.accountUnavailable }

        let ownerID = try await container.userRecordID()

        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: PartnerRecordTypes.partnership, recordID: recordID)
        record["ownerUserID"] = ownerID.recordName as CKRecordValue
        record["ownerDisplayName"] = ownerDisplayName as CKRecordValue
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

    // MARK: - Invitee side

    /// Accept a share whose metadata was delivered via
    /// `windowScene(_:userDidAcceptCloudKitShareWith:)`. Apple completes the
    /// cross-account hand-off; after this resolves, the shared records become
    /// visible via `sharedDB`.
    func acceptInvitation(metadata: CKShare.Metadata) async {
        do {
            _ = try await container.accept(metadata)
            log.notice("accepted share \(metadata.share.recordID.recordName, privacy: .public)")
            await fetchPartnerships()
            await markPartnershipAccepted(rootRecordID: metadata.hierarchicalRootRecordID)
        } catch {
            log.error("accept share failed: \(error.localizedDescription, privacy: .public)")
            self.lastError = error.localizedDescription
        }
    }

    /// Update the shared Partnership's status to accepted and stamp acceptedAt.
    /// Called on the invitee side after the share hand-off completes.
    private func markPartnershipAccepted(rootRecordID: CKRecord.ID?) async {
        guard let recordID = rootRecordID else { return }
        do {
            let record = try await sharedDB.record(for: recordID)
            record["status"] = PartnershipStatus.accepted.rawValue as CKRecordValue
            record["acceptedAt"] = Date() as CKRecordValue
            let partnerUserID = try await container.userRecordID().recordName
            record["partnerUserID"] = partnerUserID as CKRecordValue
            _ = try await sharedDB.save(record)
            await fetchPartnerships()
        } catch {
            log.error("markPartnershipAccepted failed: \(error.localizedDescription, privacy: .public)")
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
                return Partnership(from: record)
            }
        } catch {
            log.error("fetchPartnerships from \(db.databaseScope.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

// MARK: - Partnership <-> CKRecord bridging

extension Partnership {
    init?(from record: CKRecord) {
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
        self.status = status
        self.createdAt = createdAt
        self.acceptedAt = record["acceptedAt"] as? Date
        let listIDStrings = (record["associatedListIDs"] as? [String]) ?? []
        self.associatedListIDs = listIDStrings.compactMap(UUID.init)
    }
}
