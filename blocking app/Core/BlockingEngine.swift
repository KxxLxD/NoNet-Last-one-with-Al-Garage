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
        // Stop both the per-slot scheduled activities AND the time-limit activity.
        // Names that were never registered are silently ignored by stopMonitoring.
        center.stopMonitoring(allSlotActivityNames(for: list.id) + [limitActivityName(for: list.id)])
        return true
    }

    /// Convenience helper used by the UI: returns true if the list is locked by Hard Mode and
    /// the configured duration hasn't elapsed yet.
    ///
    /// Forever + Hard normally has no natural end. To satisfy Apple Guideline 5.1.1 (user
    /// control) we honour a matured `EmergencyUnlockStore` request — once the user has waited
    /// the configured delay (default 7 days), the lock releases. The delay is long enough that
    /// the lock still serves its purpose against impulse, while bounded enough that the user
    /// is never permanently held.
    ///
    /// TimeLimit + Hard also returns true (lock until midnight when the daily window resets),
    /// but does NOT honour emergency unlock — the daily reset already provides natural escape
    /// and the time-bounded nature avoids the 5.1.1 concern.
    ///
    /// Scheduled + Hard intentionally returns false here: Hard Mode on a scheduled list
    /// protects the *configuration* (delete / modify gated through the gatekeeper sheet),
    /// not the runtime shield. Pausing the block mid-window is allowed — the schedule itself
    /// releases the shield at interval end, so a "no deactivate" lock would offer no extra
    /// safety against impulse and just block legitimate pauses (e.g. quickly checking a
    /// blocked site during the user's own allowed-hours edit).
    func isHardLocked(list: ListEntity) -> Bool {
        guard list.protection == "hard" else { return false }
        if list.blockType == "forever" {
            if EmergencyUnlockStore.isGranted(for: list.id) { return false }
            return true
        }
        if list.blockType == "timeLimit" { return true }
        guard list.blockType == "now" else { return false }
        let end = list.createdAt.addingTimeInterval(TimeInterval(list.durationSeconds))
        return Date() < end
    }

    /// Cleanup on list deletion: stop monitoring, drop shields, and wipe
    /// every piece of per-list local state (selection tokens + UserDefaults
    /// satellite stores). This is the single canonical exit point — call
    /// sites that delete a list should call `purge` and then delete the
    /// Core Data row, nothing else. The per-store clears were previously
    /// duplicated across HomeView, ListDetailView, and ApprovalExecutor;
    /// centralizing here makes orphaned state impossible when a new
    /// deletion path is added.
    func purge(listId id: UUID) {
        if let store = stores.removeValue(forKey: id) {
            store.clearAllSettings()
        } else {
            // Recreate to make sure no settings linger
            ManagedSettingsStore(named: storeName(id)).clearAllSettings()
        }
        // Stop every possible activity name we might have registered for this
        // list (N per-slot scheduled + one time-limit). stopMonitoring tolerates
        // names that were never registered.
        center.stopMonitoring(allSlotActivityNames(for: id) + [limitActivityName(for: id)])
        FamilySelectionStore.clear(for: id)
        EmergencyUnlockStore.clear(for: id)
        BreaksStore.clear(for: id)
        ManualStateStore.clear(for: id)
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

    private func activityName(for id: UUID, slotIndex: Int) -> DeviceActivityName {
        DeviceActivityName(rawValue: "schedule.\(id.uuidString).\(slotIndex)")
    }

    /// Separate name prefix so the monitor extension can tell scheduled-window
    /// activities (apply shield on start) from time-limit activities (apply shield
    /// only after the threshold event fires).
    private func limitActivityName(for id: UUID) -> DeviceActivityName {
        DeviceActivityName(rawValue: "limit.\(id.uuidString)")
    }

    private func applyShields(for list: ListEntity, in store: ManagedSettingsStore) {
        // All three shield targets (apps, categories, web domains) come from
        // the FamilyActivitySelection persisted by FamilySelectionStore.
        // ManagedSettings.shield.webDomains only accepts opaque WebDomainTokens
        // produced by FamilyActivityPicker — there is no string-based path, so
        // the website-blocking UI funnels through the picker (see BlockItemsEditorView).
        guard let selection = FamilySelectionStore.load(for: list.id) else { return }
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            store.shield.webDomainCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
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

    /// Maximum slots we'll register per list. DeviceActivity has an undocumented
    /// per-extension cap (~20 active monitors); pinning per-list usage here
    /// keeps a few concurrent scheduled lists from quietly hitting that ceiling.
    /// UI in `ScheduleEditorSheet` should refuse to add more than this anyway.
    private static let maxSlotsPerList = 14

    private func scheduleMonitoring(for list: ListEntity) {
        guard let data = list.scheduleSlots else { return }
        let slots = SchedulePersistence.decode(data)
        guard !slots.isEmpty else { return }

        // One DeviceActivitySchedule per slot. The previous "earliest start /
        // latest end" merge collapsed multi-slot lists into a single window
        // (e.g. Sat 9-12 + Sat 18-22 became Sat 9-22, shielding the user
        // through their own allowed midday gap) and ignored per-day routing
        // entirely. Apple's API requires a unique `DeviceActivityName` per
        // schedule, so we encode the slot index into the name. The monitor
        // extension still gets the list UUID via prefix-stripping (see
        // BlockingMonitor.parseActivity).
        //
        // ScheduleSlotV1.day is 0=Sunday…6=Saturday; DateComponents.weekday
        // is 1=Sunday…7=Saturday, so we add 1.
        let bounded = Array(slots.prefix(Self.maxSlotsPerList))
        if slots.count > Self.maxSlotsPerList {
            log.notice("scheduleMonitoring(\(list.id, privacy: .public)): truncating \(slots.count) slots to first \(Self.maxSlotsPerList, privacy: .public) (DeviceActivity per-extension cap)")
        }
        for (index, slot) in bounded.enumerated() {
            guard slot.day >= 0 && slot.day <= 6 else {
                log.error("scheduleMonitoring: slot day=\(slot.day, privacy: .public) out of range, skipping")
                continue
            }
            // Apple requires intervalStart < intervalEnd within a single weekday.
            // Cross-midnight slots aren't a Picker-supported input (the editor
            // forces from < to), so we treat any inverted slot as a data error
            // and skip rather than guessing the user's intent.
            guard slot.fromMinutes < slot.toMinutes else {
                log.error("scheduleMonitoring: slot \(slot.id, privacy: .public) inverted (\(slot.fromMinutes, privacy: .public)→\(slot.toMinutes, privacy: .public)), skipping")
                continue
            }
            var start = DateComponents(
                hour: slot.fromMinutes / 60,
                minute: slot.fromMinutes % 60
            )
            var end = DateComponents(
                hour: slot.toMinutes / 60,
                minute: slot.toMinutes % 60
            )
            start.weekday = slot.day + 1
            end.weekday = slot.day + 1

            let schedule = DeviceActivitySchedule(
                intervalStart: start,
                intervalEnd: end,
                repeats: true
            )
            let activity = activityName(for: list.id, slotIndex: index)
            do {
                try center.startMonitoring(activity, during: schedule)
            } catch {
                log.error("startMonitoring failed for \(activity.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Stop every scheduled slot for a list. Names are deterministic
    /// (`schedule.<UUID>.<index>`) so we don't need to remember the slot count —
    /// `stopMonitoring` tolerates unknown names, and the upper bound matches
    /// `maxSlotsPerList`.
    private func allSlotActivityNames(for id: UUID) -> [DeviceActivityName] {
        (0..<Self.maxSlotsPerList).map { activityName(for: id, slotIndex: $0) }
    }
}

// TODO: Add a DeviceActivityMonitor extension target named "BlockingMonitor" in Xcode and
//       override `intervalDidStart` / `intervalDidEnd` to apply / clear shields on the same
//       ManagedSettingsStore (`ManagedSettingsStore(named: "blocklist.<UUID>")`). Without
//       this extension, scheduled lists won't trigger shields automatically; activate(list:)
//       still works for immediate ("Block now") usage.
