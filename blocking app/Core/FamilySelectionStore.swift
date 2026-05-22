//
//  FamilySelectionStore.swift
//  blocking app
//
//  Persists a per-list FamilyActivitySelection (opaque application/category/domain tokens).
//
//  Uses a shared App Group UserDefaults suite so the DeviceActivityMonitor extension
//  (which runs in a separate process) can read the same data. Falls back to standard
//  UserDefaults if the App Group capability hasn't been granted yet — keeps the app
//  functional during initial development before App Group is registered with Apple.
//

import Foundation
import FamilyControls
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "FamilySelection")
private let prefix = "v1:familySelection"

/// The App Group identifier shared between the main app and the BlockingMonitor extension.
/// Must match the value in both `.entitlements` files and be registered in Apple Developer Portal.
let kSharedAppGroup = "group.com.nonetapp.shared"

/// Shared defaults that the BlockingMonitor extension can also read from.
/// Falls back to `.standard` until the App Group capability is granted.
let sharedDefaults: UserDefaults = {
    if let shared = UserDefaults(suiteName: kSharedAppGroup) {
        return shared
    }
    log.notice("App Group \(kSharedAppGroup, privacy: .public) not available — falling back to UserDefaults.standard")
    return .standard
}()

enum FamilySelectionStore {
    private static func key(for id: UUID) -> String { "\(prefix):\(id.uuidString)" }

    static func save(_ selection: FamilyActivitySelection, for id: UUID) {
        do {
            let data = try JSONEncoder().encode(selection)
            sharedDefaults.set(data, forKey: key(for: id))
        } catch {
            log.error("Encode FamilyActivitySelection failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func load(for id: UUID) -> FamilyActivitySelection? {
        guard let data = sharedDefaults.data(forKey: key(for: id)) else { return nil }
        do {
            return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        } catch {
            log.error("Decode FamilyActivitySelection failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func clear(for id: UUID) {
        sharedDefaults.removeObject(forKey: key(for: id))
    }
}
