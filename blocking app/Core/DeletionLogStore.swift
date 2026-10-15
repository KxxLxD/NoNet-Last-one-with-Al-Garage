//
//  DeletionLogStore.swift
//  blocking app
//
//  Records the "strong reason" the user wrote when overriding the NoNet
//  gatekeeper to delete (or disable / modify) a Hard Mode list. The act of
//  having to articulate the reason is half the point of the gate; persisting
//  it lets the user look back later and see what they were thinking when they
//  broke their own commitment. No UI surfaces this list yet — it's stored so
//  a future "Reflections" screen can present it.
//
//  Local-only, UserDefaults-backed. No CloudKit sync (this is deliberately
//  private to the device — a partner's-eye view of deletion attempts already
//  exists via BreakAttempt records).
//

import Foundation
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "DeletionLog")

struct DeletionLogEntry: Codable, Identifiable {
    let id: UUID
    let listID: UUID
    let listName: String
    let actionType: String   // "delete" | "disable" | "modify"
    let reason: String
    let deletedAt: Date
}

enum DeletionLogStore {
    private static let storeKey = "v1:deletionLog:entries"

    static func append(listID: UUID, listName: String, actionType: String, reason: String, at date: Date = Date()) {
        var entries = load()
        let entry = DeletionLogEntry(
            id: UUID(),
            listID: listID,
            listName: listName,
            actionType: actionType,
            reason: reason,
            deletedAt: date
        )
        entries.append(entry)
        save(entries)
        log.notice("DeletionLogStore: appended \(actionType, privacy: .public) for list \(listID, privacy: .public)")
    }

    static func load() -> [DeletionLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return [] }
        do {
            return try JSONDecoder().decode([DeletionLogEntry].self, from: data)
        } catch {
            log.error("DeletionLogStore decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func save(_ entries: [DeletionLogEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: storeKey)
        } catch {
            log.error("DeletionLogStore encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
