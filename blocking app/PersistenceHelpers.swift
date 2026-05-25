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

/// Persists per-list emergency-unlock requests for Hard + Forever lists.
///
/// Forever + Hard Mode has no natural end: deactivate is refused, the shield
/// runs forever. Apple Review treats unrescuable user-initiated lockouts as a
/// violation of Guideline 5.1.1 (user control), so an "emergency unlock with
/// delay" pattern is required. The user requests, a counter starts, and after
/// `BlockingConstants.emergencyUnlockDelaySeconds` the request matures and
/// `BlockingEngine.deactivate(force:)` will succeed.
///
/// Storing only the *request timestamp* (not the maturity time) means we can
/// adjust the delay constant in a future release without invalidating
/// in-flight requests.
struct EmergencyUnlockStore {
    private static func key(_ id: UUID) -> String {
        "\(persistenceVersion):emergencyUnlock:requestedAt:\(id.uuidString)"
    }

    static func requestUnlock(for id: UUID, now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: key(id))
    }

    static func requestedAt(for id: UUID) -> Date? {
        let ts = UserDefaults.standard.double(forKey: key(id))
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    /// True once the request has aged past the configured delay.
    static func isGranted(for id: UUID, delay: TimeInterval = BlockingConstants.emergencyUnlockDelaySeconds, now: Date = Date()) -> Bool {
        guard let requested = requestedAt(for: id) else { return false }
        return now.timeIntervalSince(requested) >= delay
    }

    /// Seconds remaining until the request matures, or 0 if already granted /
    /// no request pending.
    static func remainingSeconds(for id: UUID, delay: TimeInterval = BlockingConstants.emergencyUnlockDelaySeconds, now: Date = Date()) -> TimeInterval {
        guard let requested = requestedAt(for: id) else { return 0 }
        let elapsed = now.timeIntervalSince(requested)
        return max(0, delay - elapsed)
    }

    static func clear(for id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(id))
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
