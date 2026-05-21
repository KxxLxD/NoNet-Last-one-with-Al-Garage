import Foundation

/// In-process version tag for UserDefaults keys.
/// Bump and add migration if a schema change is needed.
private let persistenceVersion = "v1"

struct ManualStateStore {
    private static func key(_ id: UUID, _ name: String) -> String {
        "\(persistenceVersion):manual:\(name):\(id.uuidString)"
    }

    static func isActive(for id: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: key(id, "active"))
    }

    static func startTs(for id: UUID) -> Double {
        UserDefaults.standard.double(forKey: key(id, "startTs"))
    }

    static func toggle(for id: UUID) {
        let current = isActive(for: id)
        UserDefaults.standard.set(!current, forKey: key(id, "active"))
        if !current {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key(id, "startTs"))
        } else {
            UserDefaults.standard.removeObject(forKey: key(id, "startTs"))
        }
    }

    /// Remove all manual-state keys for a list (called on list deletion).
    static func clear(for id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(id, "active"))
        UserDefaults.standard.removeObject(forKey: key(id, "startTs"))
    }
}

struct BreaksStore {
    private static func key(_ id: UUID, _ name: String) -> String {
        "\(persistenceVersion):breaks:\(name):\(id.uuidString)"
    }

    static func save(for id: UUID, count: Int, durationMinutes: Int) {
        UserDefaults.standard.set(count, forKey: key(id, "count"))
        UserDefaults.standard.set(durationMinutes, forKey: key(id, "duration"))
    }

    static func load(for id: UUID) -> (count: Int, duration: Int)? {
        let count = UserDefaults.standard.integer(forKey: key(id, "count"))
        let dur = UserDefaults.standard.integer(forKey: key(id, "duration"))
        if count == 0 && dur == 0 { return nil }
        return (count, dur)
    }

    /// Remove all break-related keys for a list (called on list deletion).
    static func clear(for id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(id, "count"))
        UserDefaults.standard.removeObject(forKey: key(id, "duration"))
    }
}

/// One-time migration: rewrite pre-versioned keys to versioned form so existing users
/// don't lose their breaks/manual-state data when upgrading.
enum PersistenceMigration {
    private static let migrationKey = "\(persistenceVersion):migration-done"

    static func runIfNeeded() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: migrationKey) else { return }

        for k in d.dictionaryRepresentation().keys {
            // Old format: "manual:active:<UUID>" / "breaks:count:<UUID>" (no version prefix).
            guard k.hasPrefix("manual:") || k.hasPrefix("breaks:") else { continue }
            let newKey = "\(persistenceVersion):\(k)"
            if d.object(forKey: newKey) == nil {
                if let v = d.object(forKey: k) {
                    d.set(v, forKey: newKey)
                }
            }
            d.removeObject(forKey: k)
        }
        d.set(true, forKey: migrationKey)
    }
}
