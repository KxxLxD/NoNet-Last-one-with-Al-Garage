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

        guard let id = parseListId(from: activity) else { return }
        let store = ManagedSettingsStore(named: .init(rawValue: "blocklist.\(id.uuidString)"))

        // Read the persisted FamilyActivitySelection from the shared App Group defaults
        // (same key the main app's FamilySelectionStore writes to).
        if let data = sharedDefaults.data(forKey: "v1:familySelection:\(id.uuidString)"),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
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
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log.notice("intervalDidEnd: \(activity.rawValue, privacy: .public)")

        guard let id = parseListId(from: activity) else { return }
        let store = ManagedSettingsStore(named: .init(rawValue: "blocklist.\(id.uuidString)"))
        store.clearAllSettings()
    }

    /// activity.rawValue is "schedule.<UUID>" — extract the UUID.
    private func parseListId(from activity: DeviceActivityName) -> UUID? {
        let prefix = "schedule."
        let raw = activity.rawValue
        guard raw.hasPrefix(prefix) else { return nil }
        let idStr = String(raw.dropFirst(prefix.count))
        return UUID(uuidString: idStr)
    }
}
