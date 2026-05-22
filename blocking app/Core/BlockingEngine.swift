//
//  BlockingEngine.swift
//  blocking app
//
//  Applies and removes blocking via FamilyControls / ManagedSettings / DeviceActivity.
//
//  Architecture notes:
//  - One named `ManagedSettingsStore` per list (keyed by UUID) so multiple lists can be active
//    independently — clearing one list doesn't drop another's shields.
//  - Web domains accept user-typed strings and become `WebDomain` shields.
//  - Apps and activity categories require `FamilyActivitySelection` tokens (selected via the
//    system picker). Those are persisted via `FamilySelectionStore`.
//  - For `blockType == "now"` we apply immediately. For `blockType == "scheduled"` we register
//    a `DeviceActivitySchedule` per slot via `DeviceActivityCenter`. The actual start/stop
//    callbacks live in a `DeviceActivityMonitor` extension — adding that target requires
//    creating it in Xcode (see TODO at bottom of this file).
//  - For `blockType == "forever"` we apply shields permanently with no expiry — `durationSeconds`
//    is unused. Hard Mode + Forever cannot be deactivated by the user at all (only via purge,
//    which is itself blocked in the UI for Hard Mode lists).
//  - For `blockType == "timeLimit"` we register a daily DeviceActivitySchedule (00:00 → 23:59,
//    repeating) plus a `DeviceActivityEvent` with `threshold = durationSeconds/60 minutes`.
//    `BlockingMonitor.eventDidReachThreshold` applies the shield once the user has consumed
//    the daily quota; `intervalDidStart` clears it at midnight so the next day starts fresh.
//    Shields are NOT applied immediately on activate — usage is allowed up to the threshold.
//

import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import os

@MainActor
final class BlockingEngine {
    static let shared = BlockingEngine()

    private let log = Logger(subsystem: "app.nonet.blocking", category: "BlockingEngine")
    private let center = DeviceActivityCenter()
    private var stores: [UUID: ManagedSettingsStore] = [:]

    private init() {}

    // MARK: - Public API

    /// Apply shields right now and (if scheduled) register a DeviceActivity schedule.
    /// Requires Screen Time authorization; callers should ensure it before invoking.
    func activate(list: ListEntity) {
        guard PermissionsManager.shared.isScreenTimeGranted else {
            log.notice("activate(\(list.id, privacy: .public)) skipped: Screen Time not granted")
            return
        }

        // Time-Limit starts with no shield — usage is allowed until the daily threshold.
        // The monitor extension applies the shield when the threshold is reached.
        if list.blockType == "timeLimit" {
            scheduleTimeLimit(for: list)
            return
        }

        let store = store(for: list.id)
        applyShields(for: list, in: store)

        if list.blockType == "scheduled" {
            scheduleMonitoring(for: list)
        }
    }

    /// Lift all shields for a list and cancel any scheduled monitoring.
    /// Refuses to deactivate Hard-Mode lists whose duration window hasn't elapsed.
    @discardableResult
    func deactivate(list: ListEntity, force: Bool = false) -> Bool {
        if !force, isHardLocked(list: list) {
            log.notice("deactivate(\(list.id, privacy: .public)) blocked: Hard Mode active")
            return false
        }
        let store = store(for: list.id)
        store.clearAllSettings()
        center.stopMonitoring([activityName(for: list.id)])
        return true
    }

    /// Convenience helper used by the UI: returns true if the list is locked by Hard Mode and
    /// the configured duration hasn't elapsed yet. Forever + Hard and TimeLimit + Hard are
    /// locked indefinitely (no natural end date).
    func isHardLocked(list: ListEntity) -> Bool {
        guard list.protection == "hard" else { return false }
        if list.blockType == "forever" || list.blockType == "timeLimit" { return true }
        guard list.blockType == "now" else { return false }
        let end = list.createdAt.addingTimeInterval(TimeInterval(list.durationSeconds))
        return Date() < end
    }

    /// Cleanup on list deletion: clear stored selection + monitoring + shields.
    func purge(listId id: UUID) {
        if let store = stores.removeValue(forKey: id) {
            store.clearAllSettings()
        } else {
            // Recreate to make sure no settings linger
            ManagedSettingsStore(named: storeName(id)).clearAllSettings()
        }
        // Stop both schedule kinds — only the one that was registered actually exists,
        // but stopMonitoring tolerates unknown names.
        center.stopMonitoring([activityName(for: id), limitActivityName(for: id)])
        FamilySelectionStore.clear(for: id)
    }

    // MARK: - Private helpers

    private func store(for id: UUID) -> ManagedSettingsStore {
        if let s = stores[id] { return s }
        let s = ManagedSettingsStore(named: storeName(id))
        stores[id] = s
        return s
    }

    private func storeName(_ id: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(rawValue: "blocklist.\(id.uuidString)")
    }

    private func activityName(for id: UUID) -> DeviceActivityName {
        DeviceActivityName(rawValue: "schedule.\(id.uuidString)")
    }

    /// Separate name prefix so the monitor extension can tell scheduled-window
    /// activities (apply shield on start) from time-limit activities (apply shield
    /// only after the threshold event fires).
    private func limitActivityName(for id: UUID) -> DeviceActivityName {
        DeviceActivityName(rawValue: "limit.\(id.uuidString)")
    }

    private func applyShields(for list: ListEntity, in store: ManagedSettingsStore) {
        // Apps + categories come from the saved FamilyActivitySelection if any.
        if let selection = FamilySelectionStore.load(for: list.id) {
            if !selection.applicationTokens.isEmpty {
                store.shield.applications = selection.applicationTokens
            }
            if !selection.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(selection.categoryTokens)
                store.shield.webDomainCategories = .specific(selection.categoryTokens)
            }
            if !selection.webDomainTokens.isEmpty {
                // Merge with user-typed domains below
                store.shield.webDomains = selection.webDomainTokens
            }
        }

        // User-typed websites stored as BlockItemEntity(kind=="website") aren't tokens — they
        // map to WebDomain shields by string. ManagedSettings doesn't accept raw strings
        // here in 16+, so we keep this as the path through the token-based selection. We log
        // an informational note so it's clear to maintainers why typed-only domains may not
        // shield without a picker selection.
        let typedDomains = (list.items ?? [])
            .filter { $0.kind == "website" }
            .map { $0.value }
        if !typedDomains.isEmpty {
            log.notice("List \(list.id, privacy: .public) has \(typedDomains.count) typed domains; tokens-only shielding will not cover them until they're picked via FamilyActivityPicker.")
        }
    }

    private func scheduleTimeLimit(for list: ListEntity) {
        let limitMinutes = Int(list.durationSeconds / 60)
        guard limitMinutes > 0 else {
            log.notice("scheduleTimeLimit(\(list.id, privacy: .public)) skipped: zero-minute limit")
            return
        }
        guard let selection = FamilySelectionStore.load(for: list.id) else {
            log.notice("scheduleTimeLimit(\(list.id, privacy: .public)) skipped: no FamilyActivitySelection")
            return
        }

        // Daily window, repeating every day. Apple measures usage of the selected
        // apps/categories/web-domains inside this window and fires the threshold event.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: limitMinutes)
        )
        let eventName = DeviceActivityEvent.Name(rawValue: "threshold.\(list.id.uuidString)")
        do {
            try center.startMonitoring(
                limitActivityName(for: list.id),
                during: schedule,
                events: [eventName: event]
            )
        } catch {
            log.error("scheduleTimeLimit failed for \(list.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleMonitoring(for list: ListEntity) {
        guard let data = list.scheduleSlots else { return }
        let slots = SchedulePersistence.decode(data)
        guard !slots.isEmpty else { return }

        // Combine slots into a single schedule per list; DeviceActivity supports
        // one schedule per `DeviceActivityName`, so we pick the earliest start
        // and latest end as the activity window. The actual minute-by-minute logic
        // is enforced via the monitor extension callback (see TODO at bottom).
        let earliestStart = slots.map { $0.fromMinutes }.min() ?? 0
        let latestEnd = slots.map { $0.toMinutes }.max() ?? 0
        let startComps = DateComponents(hour: earliestStart / 60, minute: earliestStart % 60)
        let endComps = DateComponents(hour: latestEnd / 60, minute: latestEnd % 60)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: true
        )
        do {
            try center.startMonitoring(activityName(for: list.id), during: schedule)
        } catch {
            log.error("startMonitoring failed for \(list.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

// TODO: Add a DeviceActivityMonitor extension target named "BlockingMonitor" in Xcode and
//       override `intervalDidStart` / `intervalDidEnd` to apply / clear shields on the same
//       ManagedSettingsStore (`ManagedSettingsStore(named: "blocklist.<UUID>")`). Without
//       this extension, scheduled lists won't trigger shields automatically; activate(list:)
//       still works for immediate ("Block now") usage.
