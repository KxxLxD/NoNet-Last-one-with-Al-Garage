import Foundation
import FamilyControls

enum ProtectionMode: String, Codable, CaseIterable, Sendable {
    /// Can be edited, stopped or deleted at any time.
    case none = "noProtection"
    /// Locked while active: no edits, no stopping, no breaks, and Samla can't be uninstalled.
    case hard
    /// Locked while active unless the accountability partner enters their PIN.
    case partner
}

enum BlockKind: String, Codable, CaseIterable, Sendable {
    /// Runs as a one-off session for `durationSeconds`.
    case now
    /// Runs automatically during weekly schedule slots.
    case scheduled
}

/// A weekly time window. `day` is 0 = Sunday … 6 = Saturday (Calendar weekday − 1).
struct ScheduleSlot: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var day: Int
    var fromMinutes: Int
    var toMinutes: Int

    /// Slots ending at or before their start run past midnight into the next day.
    var isOvernight: Bool { toMinutes <= fromMinutes }

    var durationMinutes: Int {
        isOvernight ? (24 * 60 - fromMinutes) + toMinutes : toMinutes - fromMinutes
    }

    func contains(day currentDay: Int, minute: Int) -> Bool {
        if !isOvernight {
            return currentDay == day && minute >= fromMinutes && minute < toMinutes
        }
        return (currentDay == day && minute >= fromMinutes)
            || (currentDay == (day + 1) % 7 && minute < toMinutes)
    }
}

struct BreakPolicy: Codable, Hashable, Sendable {
    /// Breaks allowed per rolling 24 hours.
    var count = 0
    var minutes = 5
}

/// A block list and its runtime state. Persisted as JSON in the App Group so the
/// monitor extension can re-apply shields without launching the app.
struct BlockList: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var protection: ProtectionMode = .none
    var kind: BlockKind = .now
    var durationSeconds = 30 * 60
    var slots: [ScheduleSlot] = []
    var websites: [String] = []
    var selection = FamilyActivitySelection()
    var blockAdultContent = false
    var breaks = BreakPolicy()
    var createdAt = Date()
    var updatedAt = Date()

    // Runtime state
    var session: DateInterval?
    var breakUntil: Date?
    var breakStarts: [Date] = []

    init(name: String) {
        self.name = name
    }

    // Tolerant decoding so new fields never break previously saved data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        protection = try c.decodeIfPresent(ProtectionMode.self, forKey: .protection) ?? .none
        kind = try c.decodeIfPresent(BlockKind.self, forKey: .kind) ?? .now
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 30 * 60
        slots = try c.decodeIfPresent([ScheduleSlot].self, forKey: .slots) ?? []
        websites = try c.decodeIfPresent([String].self, forKey: .websites) ?? []
        selection = (try? c.decodeIfPresent(FamilyActivitySelection.self, forKey: .selection)) ?? FamilyActivitySelection()
        blockAdultContent = try c.decodeIfPresent(Bool.self, forKey: .blockAdultContent) ?? false
        breaks = try c.decodeIfPresent(BreakPolicy.self, forKey: .breaks) ?? BreakPolicy()
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        session = try c.decodeIfPresent(DateInterval.self, forKey: .session)
        breakUntil = try c.decodeIfPresent(Date.self, forKey: .breakUntil)
        breakStarts = try c.decodeIfPresent([Date].self, forKey: .breakStarts) ?? []
    }
}

// MARK: - Activity rules

extension BlockList {
    var isHard: Bool { protection == .hard }
    var isPartnerProtected: Bool { protection == .partner }

    /// Whether the list is inside its blocking window (ignoring breaks).
    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        switch kind {
        case .now:
            guard let session else { return false }
            return session.start <= date && date < session.end
        case .scheduled:
            let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
            guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return false }
            let minuteOfDay = hour * 60 + minute
            return slots.contains { $0.contains(day: weekday - 1, minute: minuteOfDay) }
        }
    }

    /// When the current blocking window ends, or nil if the list isn't active.
    func activeUntil(at date: Date, calendar: Calendar = .current) -> Date? {
        guard isActive(at: date, calendar: calendar) else { return nil }
        switch kind {
        case .now:
            return session?.end
        case .scheduled:
            let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
            guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return nil }
            let today = weekday - 1
            let minuteOfDay = hour * 60 + minute
            guard let slot = slots.first(where: { $0.contains(day: today, minute: minuteOfDay) }) else { return nil }
            // An overnight slot that started today ends tomorrow.
            let endsTomorrow = slot.isOvernight && slot.day == today && minuteOfDay >= slot.fromMinutes
            let startOfDay = calendar.startOfDay(for: date)
            let endDay = endsTomorrow ? calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay : startOfDay
            return calendar.date(byAdding: .minute, value: slot.toMinutes, to: endDay)
        }
    }

    func isOnBreak(at date: Date) -> Bool {
        guard let breakUntil else { return false }
        return date < breakUntil
    }

    /// Whether shields for this list should be up right now.
    func isShielding(at date: Date) -> Bool {
        isActive(at: date) && !isOnBreak(at: date)
    }

    /// Protected lists can't be edited, stopped or deleted while active
    /// (Hard Mode: not at all; partner: only with the partner's PIN).
    func isLocked(at date: Date) -> Bool {
        protection != .none && isActive(at: date)
    }

    /// Hard Mode allows no breaks; other protections allow the pre-agreed ones.
    var allowsBreaks: Bool { !isHard && breaks.count > 0 }

    func breaksRemaining(at date: Date) -> Int {
        guard allowsBreaks else { return 0 }
        let used = breakStarts.filter { date.timeIntervalSince($0) < 24 * 3600 }.count
        return max(0, breaks.count - used)
    }

    var appCount: Int { selection.applicationTokens.count }
    var categoryCount: Int { selection.categoryTokens.count }
    var websiteCount: Int { websites.count + selection.webDomainTokens.count }

    var hasItems: Bool {
        appCount + categoryCount + websiteCount > 0 || blockAdultContent
    }
}
