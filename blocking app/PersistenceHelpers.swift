import Foundation

struct ManualStateStore {
    private static func key(_ id: UUID, _ name: String) -> String { "manual:\(name):\(id.uuidString)" }
    static func isActive(for id: UUID) -> Bool { UserDefaults.standard.bool(forKey: key(id, "active")) }
    static func startTs(for id: UUID) -> Double { UserDefaults.standard.double(forKey: key(id, "startTs")) }
    static func toggle(for id: UUID) {
        let current = isActive(for: id)
        UserDefaults.standard.set(!current, forKey: key(id, "active"))
        if !current {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key(id, "startTs"))
        } else {
            UserDefaults.standard.removeObject(forKey: key(id, "startTs"))
        }
    }
}

struct BreaksStore {
    private static func key(_ id: UUID, _ name: String) -> String { "breaks:\(name):\(id.uuidString)" }
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
} 