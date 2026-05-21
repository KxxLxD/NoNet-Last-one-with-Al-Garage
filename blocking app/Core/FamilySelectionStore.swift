//
//  FamilySelectionStore.swift
//  blocking app
//
//  Persists a per-list FamilyActivitySelection (opaque application/category/domain tokens).
//  Stored in UserDefaults because the Core Data model is built programmatically; using UserDefaults
//  keeps the model stable while still keying selections by the list's UUID.
//

import Foundation
import FamilyControls
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "FamilySelection")
private let prefix = "v1:familySelection"

enum FamilySelectionStore {
    private static func key(for id: UUID) -> String { "\(prefix):\(id.uuidString)" }

    static func save(_ selection: FamilyActivitySelection, for id: UUID) {
        do {
            let data = try JSONEncoder().encode(selection)
            UserDefaults.standard.set(data, forKey: key(for: id))
        } catch {
            log.error("Encode FamilyActivitySelection failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func load(for id: UUID) -> FamilyActivitySelection? {
        guard let data = UserDefaults.standard.data(forKey: key(for: id)) else { return nil }
        do {
            return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        } catch {
            log.error("Decode FamilyActivitySelection failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func clear(for id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: id))
    }
}
