//
//  FamilySelectionStore.swift
//  blocking app
//
//  Persists a per-list FamilyActivitySelection (opaque application/category/domain tokens).
//
//  The main app and BlockingMonitor extension run in separate sandboxes. A shared
//  App Group UserDefaults suite is the only way they can read the same data —
//  each process's `.standard` resolves to a different on-disk container. So when
//  the App Group capability is missing or wrong, writes from the app are invisible
//  to the extension and Scheduled/Time-Limit blocks fail silently. Surfacing this
//  explicitly is preferable to the prior silent fallback to `.standard`.
//

import Foundation
import FamilyControls
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "FamilySelection")
private let prefix = "v1:familySelection"

/// The App Group identifier shared between the main app and the BlockingMonitor extension.
/// Must match the value in both `.entitlements` files and be registered in Apple Developer Portal.
let kSharedAppGroup = "group.com.nonetapp.shared"

/// True once the App Group capability has been granted to this process. Read by
/// HomeView to surface the "extension can't see data" banner. Computed once at
/// load — process restart picks up newly granted capabilities.
let isAppGroupActive: Bool = (UserDefaults(suiteName: kSharedAppGroup) != nil)

/// App Group suite, or `nil` if the capability isn't granted yet. Prefer this
/// over `sharedDefaults` for new code — checking for nil makes the data-isolation
/// hazard explicit at the call site.
let sharedDefaultsOptional: UserDefaults? = UserDefaults(suiteName: kSharedAppGroup)

/// Legacy alias that returns the App Group suite or `.standard` as fallback.
/// **Hazard**: when the capability is missing, writes here are NOT visible to
/// the extension — Scheduled and Time-Limit blocks will silently apply no shield.
/// Existing callers tolerated this during initial dev; new callers should branch
/// on `isAppGroupActive` and refuse to persist when false.
let sharedDefaults: UserDefaults = {
    if let shared = sharedDefaultsOptional { return shared }
    log.error("App Group \(kSharedAppGroup, privacy: .public) NOT GRANTED — extension will not see writes. Scheduled/Time-Limit blocks will silently fail until capability is added in Xcode and entitlements provisioned.")
    return .standard
}()

enum FamilySelectionStore {
    private static func key(for id: UUID) -> String { "\(prefix):\(id.uuidString)" }

    /// Persist the user's app/category/domain selection.
    /// Returns false if the App Group is missing — caller should warn the user
    /// that Scheduled/Time-Limit lists won't trigger until capabilities are fixed.
    @discardableResult
    static func save(_ selection: FamilyActivitySelection, for id: UUID) -> Bool {
        guard let defaults = sharedDefaultsOptional else {
            log.error("save(\(id, privacy: .public)) skipped: App Group missing — extension cannot see this selection")
            return false
        }
        do {
            let data = try JSONEncoder().encode(selection)
            defaults.set(data, forKey: key(for: id))
            return true
        } catch {
            log.error("Encode FamilyActivitySelection failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func load(for id: UUID) -> FamilyActivitySelection? {
        guard let defaults = sharedDefaultsOptional else {
            log.notice("load(\(id, privacy: .public)) skipped: App Group missing")
            return nil
        }
        guard let data = defaults.data(forKey: key(for: id)) else { return nil }
        do {
            return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        } catch {
            log.error("Decode FamilyActivitySelection failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func clear(for id: UUID) {
        sharedDefaultsOptional?.removeObject(forKey: key(for: id))
    }
}
