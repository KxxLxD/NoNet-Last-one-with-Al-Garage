//
//  PendingBreakAttemptQueue.swift
//  blocking app
//
//  Local fallback queue for BreakAttempt records that CloudKit couldn't accept
//  yet (offline, account temporarily unavailable, network failure, etc.).
//
//  Background: the Recovery Partner promise is "your partner gets notified when
//  you try to break Hard Mode." Before this queue, `recordBreakAttempt` was
//  fire-and-forget — any CloudKit error swallowed the attempt silently, and the
//  partner never received a push. That broke the social-accountability
//  contract in exactly the situation users felt least supervised (offline).
//
//  Design: persist the minimum data needed to reconstruct the CKRecord on
//  retry. Replay on every successful network/account state transition (the
//  CKAccountChanged listener in ContentView and on every fetchPartnerships
//  call). Records that succeed are removed from the queue; ones that still
//  fail stay and retry later.
//
//  Storage: a single JSON-encoded array in UserDefaults under a `v1:` prefix.
//  Not in the App Group — only the main app records and replays attempts; the
//  extension doesn't need to see this queue. Cap kept tight (50 entries) so a
//  user who is offline for weeks doesn't accumulate unbounded state.
//

import Foundation
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "PendingBreakAttempts")

struct PendingBreakAttempt: Codable, Identifiable, Equatable {
    let id: UUID
    let partnershipID: String
    let listID: UUID
    let listName: String
    let attemptedAt: Date
    let typeRaw: String
    let reachedThrough: String?
    /// Approval-workflow status. nil on records enqueued before this field
    /// existed — those all originated from `recordBreakAttempt`, which is the
    /// .logOnly path. Decode treats nil as `.logOnly` so legacy queue entries
    /// keep flushing unchanged.
    let statusRaw: String?
    /// Optional user-written reason — only set for `.pending` requests from
    /// `createActionRequest`. Legacy records have nil.
    let reason: String?

    var type: BreakAttemptType {
        BreakAttemptType(rawValue: typeRaw) ?? .disable
    }

    var status: RequestStatus {
        guard let raw = statusRaw else { return .logOnly }
        return RequestStatus(rawValue: raw) ?? .logOnly
    }
}

enum PendingBreakAttemptQueue {
    private static let key = "v1:pendingBreakAttempts"
    private static let maxQueueSize = 50

    static func enqueue(_ attempt: PendingBreakAttempt) {
        var current = load()
        current.append(attempt)
        // Drop oldest if we somehow exceed the cap — losing an old record is
        // better than blowing up UserDefaults on a user who hasn't been online
        // for months.
        if current.count > maxQueueSize {
            current = Array(current.suffix(maxQueueSize))
            log.notice("PendingBreakAttemptQueue capped at \(maxQueueSize) entries, dropped oldest")
        }
        save(current)
        log.notice("enqueued attempt \(attempt.id, privacy: .public) for list \(attempt.listID, privacy: .public). queue depth=\(current.count)")
    }

    static func load() -> [PendingBreakAttempt] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([PendingBreakAttempt].self, from: data)
        } catch {
            log.error("decode pending queue failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    static func remove(id: UUID) {
        var current = load()
        current.removeAll { $0.id == id }
        save(current)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static var depth: Int { load().count }

    private static func save(_ attempts: [PendingBreakAttempt]) {
        do {
            let data = try JSONEncoder().encode(attempts)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            log.error("encode pending queue failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
