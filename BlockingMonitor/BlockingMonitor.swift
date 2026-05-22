//
//  BlockingMonitor.swift
//  BlockingMonitor (DeviceActivityMonitor extension)
//
//  Apple invokes these callbacks in a separate process when a scheduled DeviceActivity
//  starts or ends. The extension must apply shields on the SAME `ManagedSettingsStore`
//  name that BlockingEngine uses ("blocklist.<UUID>") so the rest of the app stays in sync.
//
//  SETUP IN XCODE (one-time, ~30 seconds):
//  1. File → New → Target → "Device Activity Monitor Extension"
//  2. Product Name: BlockingMonitor
//  3. Bundle Identifier: com.nonetapp.BlockingMonitor
//  4. Embed in app: blocking app
//  5. Replace the generated `DeviceActivityMonitor.swift` with this file.
//  6. Add Family Controls capability to the extension target.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "Monitor")

/// Must match the App Group ID in both .entitlements files and the main app's FamilySelectionStore.
private let kSharedAppGroup = "group.com.nonetapp.shared"
private let sharedDefaults: UserDefaults = UserDefaults(suiteName: kSharedAppGroup) ?? .standard

class BlockingMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log.notice("intervalDidStart: \(activity.rawValue, privacy: .public)")

        guard let parsed = parseActivity(activity) else { return }
        let store = ManagedSettingsStore(named: .init(rawValue: "blocklist.\(parsed.id.uuidString)"))

        switch parsed.kind {
        case .scheduled:
            // Scheduled window opens — apply shield right away.
            applyShield(to: store, for: parsed.id)
        case .timeLimit:
            // New day for a daily-quota list — start fresh, no shield.
            // BlockingMonitor.eventDidReachThreshold will re-apply once the user crosses
            // the daily threshold.
            store.clearAllSettings()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log.notice("intervalDidEnd: \(activity.rawValue, privacy: .public)")

        guard let parsed = parseActivity(activity) else { return }
        let store = ManagedSettingsStore(named: .init(rawValue: "blocklist.\(parsed.id.uuidString)"))
        store.clearAllSettings()
    }

    /// Fired by iOS once the user's measured usage of the selected apps/categories/web-domains
    /// crosses the configured `DeviceActivityEvent.threshold`. Only fires for Time-Limit
    /// activities (they're the only ones that register events).
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        log.notice("eventDidReachThreshold: \(event.rawValue, privacy: .public) in \(activity.rawValue, privacy: .public)")

        guard let parsed = parseActivity(activity), parsed.kind == .timeLimit else { return }
        let store = ManagedSettingsStore(named: .init(rawValue: "blocklist.\(parsed.id.uuidString)"))
        applyShield(to: store, for: parsed.id)
    }

    private func applyShield(to store: ManagedSettingsStore, for id: UUID) {
        // Read the persisted FamilyActivitySelection from the shared App Group defaults
        // (same key the main app's FamilySelectionStore writes to).
        guard let data = sharedDefaults.data(forKey: "v1:familySelection:\(id.uuidString)"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            log.notice("applyShield(\(id, privacy: .public)) skipped: no persisted selection")
            return
        }
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

    private enum ActivityKind { case scheduled, timeLimit }

    /// Activity names are "schedule.<UUID>" for time-window monitoring or
    /// "limit.<UUID>" for daily quota monitoring (different shield semantics).
    private func parseActivity(_ activity: DeviceActivityName) -> (id: UUID, kind: ActivityKind)? {
        let raw = activity.rawValue
        if raw.hasPrefix("schedule.") {
            let idStr = String(raw.dropFirst("schedule.".count))
            if let id = UUID(uuidString: idStr) { return (id, .scheduled) }
        }
        if raw.hasPrefix("limit.") {
            let idStr = String(raw.dropFirst("limit.".count))
            if let id = UUID(uuidString: idStr) { return (id, .timeLimit) }
        }
        return nil
    }
}
