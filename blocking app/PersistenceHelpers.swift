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
///
/// `ObservableObject` so views observing the store see request / clear edits
/// in real time. Previously this was a struct with static methods, which
/// meant `ListDetailView` had to maintain a `@State` UUID "nonce" to force
/// re-render after requestUnlock / clear — now the @Published `requestedAtByID`
/// drives that automatically, and any view rendering off the same store
/// (e.g. HomeView's countdown badge) updates together.
@MainActor
final class EmergencyUnlockStore: ObservableObject {
    static let shared = EmergencyUnlockStore()

    /// Source of truth for the request timestamps. Mirrors what's in
    /// UserDefaults so views can observe; writes go both places at once.
    @Published private(set) var requestedAtByID: [UUID: Date] = [:]

    private static let keyPrefix = "\(persistenceVersion):emergencyUnlock:requestedAt:"

    private init() {
        // Hydrate from UserDefaults so a relaunch picks up in-flight requests.
        let d = UserDefaults.standard
        for k in d.dictionaryRepresentation().keys where k.hasPrefix(Self.keyPrefix) {
            let uuidString = String(k.dropFirst(Self.keyPrefix.count))
            guard let uuid = UUID(uuidString: uuidString) else { continue }
            let ts = d.double(forKey: k)
            if ts > 0 {
                requestedAtByID[uuid] = Date(timeIntervalSince1970: ts)
            }
        }
    }

    private static func key(_ id: UUID) -> String {
        "\(keyPrefix)\(id.uuidString)"
    }

    func requestUnlock(for id: UUID, now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Self.key(id))
        requestedAtByID[id] = now
    }

    func requestedAt(for id: UUID) -> Date? {
        requestedAtByID[id]
    }

    /// True once the request has aged past the configured delay.
    func isGranted(for id: UUID, delay: TimeInterval = BlockingConstants.emergencyUnlockDelaySeconds, now: Date = Date()) -> Bool {
        guard let requested = requestedAtByID[id] else { return false }
        return now.timeIntervalSince(requested) >= delay
    }

    /// Seconds remaining until the request matures, or 0 if already granted /
    /// no request pending.
    func remainingSeconds(for id: UUID, delay: TimeInterval = BlockingConstants.emergencyUnlockDelaySeconds, now: Date = Date()) -> TimeInterval {
        guard let requested = requestedAtByID[id] else { return 0 }
        let elapsed = now.timeIntervalSince(requested)
        return max(0, delay - elapsed)
    }

    func clear(for id: UUID) {
        UserDefaults.standard.removeObject(forKey: Self.key(id))
        requestedAtByID.removeValue(forKey: id)
    }
}

/// One-time migration: rewrite pre-versioned keys to the `v1:` schema so
/// existing users don't lose data when AppStorageKeys names change.
///
/// Two key families are migrated:
///
///   1. Per-list satellite stores (`manual:`, `breaks:`) that used to live
///      without a version prefix — they're now `v1:manual:...`, `v1:breaks:...`.
///
///   2. Single AppStorage values whose names changed from unversioned ↔ v1:
///      prefixed. The mapping is explicit (not a scan) so adding a key
///      in the future is a conscious decision and untouched legacy keys
///      can't accidentally be migrated.
enum PersistenceMigration {
    /// Bump this suffix every time the migration body changes in a way that
    /// existing installs need to re-run. The pre-rename installs have
    /// `v1:migration-done` set from a prior release, but those installs
    /// also need the AppStorage key renames added here — they get them on
    /// next launch via this new key.
    private static let migrationKey = "\(persistenceVersion):migration-done.renames-v2"

    /// Per-key (old → new) renames for AppStorage settings. The right-hand
    /// side must match `AppStorageKeys` exactly. When you bump the schema,
    /// add to this list rather than scanning all keys — a typo in one
    /// constant would silently drop user data on next launch.
    private static let appStorageRenames: [(legacy: String, current: String)] = [
        ("isAuthenticated",          "v1:isAuthenticated"),
        ("showOnboardingAfterLogin", "v1:showOnboardingAfterLogin"),
        ("isPremium",                "v1:isPremium"),
        ("trialStartTs",             "v1:trialStartTs"),
        ("hasShownTrialExpiredAlert", "v1:hasShownTrialExpiredAlert"),
        ("selectedTab",              "v1:selectedTab"),
        ("ob_name",                  "v1:obName"),
        ("ob_gender",                "v1:obGender"),
        ("ob_age_group",             "v1:obAgeGroup"),
        ("ob_apps",                  "v1:obApps"),
        ("ob_apps_other",            "v1:obAppsOther"),
        ("ob_cats",                  "v1:obCats"),
        ("ob_cats_other",            "v1:obCatsOther"),
        ("ob_goals",                 "v1:obGoals"),
        ("ob_goals_other",           "v1:obGoalsOther"),
        ("seed_v1_done",             "v1:seedDone"),
    ]

    static func runIfNeeded() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: migrationKey) else { return }

        // Per-list satellite stores (UUID-keyed).
        for k in d.dictionaryRepresentation().keys {
            guard k.hasPrefix("manual:") || k.hasPrefix("breaks:") else { continue }
            let newKey = "\(persistenceVersion):\(k)"
            if d.object(forKey: newKey) == nil, let v = d.object(forKey: k) {
                d.set(v, forKey: newKey)
            }
            d.removeObject(forKey: k)
        }

        // Single-value AppStorage renames.
        for (legacy, current) in appStorageRenames {
            // Don't clobber a value the user already wrote to the new key
            // (would happen if migration ran partially before failing).
            if d.object(forKey: current) == nil, let v = d.object(forKey: legacy) {
                d.set(v, forKey: current)
            }
            d.removeObject(forKey: legacy)
        }

        d.set(true, forKey: migrationKey)
    }
}
