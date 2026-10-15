//
//  SchedulePersistence.swift
//  blocking app
//
//  Versioned encode/decode for the `scheduleSlots` binary field on ListEntity.
//  Bumping `currentVersion` requires writing a migration in `decode(_:)`.
//

import Foundation
import os

private let scheduleLog = Logger(subsystem: "app.nonet.blocking", category: "SchedulePersistence")

struct ScheduleSlotV1: Codable, Hashable {
    let id: UUID
    let day: Int
    let fromMinutes: Int
    let toMinutes: Int
}

private struct ScheduleSlotsPayload: Codable {
    let version: Int
    let slots: [ScheduleSlotV1]
}

enum SchedulePersistence {
    private static let currentVersion = 1

    static func encode(_ slots: [ScheduleSlotV1]) -> Data? {
        let payload = ScheduleSlotsPayload(version: currentVersion, slots: slots)
        do {
            return try JSONEncoder().encode(payload)
        } catch {
            scheduleLog.error("Schedule encode failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func decode(_ data: Data) -> [ScheduleSlotV1] {
        // New versioned format
        if let payload = try? JSONDecoder().decode(ScheduleSlotsPayload.self, from: data) {
            switch payload.version {
            case 1: return payload.slots
            default:
                scheduleLog.error("Unknown schedule version: \(payload.version, privacy: .public)")
                return []
            }
        }
        // Legacy fallback: bare array (pre-versioning)
        if let legacy = try? JSONDecoder().decode([ScheduleSlotV1].self, from: data) {
            scheduleLog.notice("Decoded legacy (un-versioned) schedule slots — will be re-saved with version on next edit")
            return legacy
        }
        scheduleLog.error("Failed to decode schedule slots payload")
        return []
    }
}
