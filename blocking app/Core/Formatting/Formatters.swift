import Foundation

/// Locale-aware formatting for days, times and durations. Everything follows the app's
/// language (including Arabic digits), so no manual per-language string building is needed.
enum Formatters {
    /// `day` is 0 = Sunday … 6 = Saturday.
    static func weekday(_ day: Int, short: Bool = false) -> String {
        let calendar = Calendar.current
        let symbols = short ? calendar.shortWeekdaySymbols : calendar.weekdaySymbols
        return symbols[((day % 7) + 7) % 7]
    }

    static func time(minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: (minutes / 60) % 24, minute: minutes % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// A clock time ("6:00 AM"), with the day added when it isn't today ("Tue 6:00 AM").
    static func clock(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        let withinWeek = date.timeIntervalSince(now) < 6 * 86_400
        return withinWeek
            ? date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
            : date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    static func timeRange(from: Int, to: Int) -> String {
        "\(time(minutes: from))–\(time(minutes: to))"
    }

    static func duration(seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.days, .hours, .minutes], width: .abbreviated))
    }

    static func duration(minutes: Int) -> String {
        duration(seconds: minutes * 60)
    }

    /// e.g. "Sun–Thu 9:00 AM–5:00 PM" when all slots share one time range, otherwise a count.
    static func scheduleSummary(_ slots: [ScheduleSlot]) -> String {
        guard let first = slots.first else { return String(localized: "No schedule yet") }
        let sameTime = slots.allSatisfy { $0.fromMinutes == first.fromMinutes && $0.toMinutes == first.toMinutes }
        guard sameTime else { return String(localized: "\(slots.count) time slots") }

        let days = Array(Set(slots.map(\.day))).sorted()
        let isContiguous = days.count >= 2 && zip(days, days.dropFirst()).allSatisfy { $1 == $0 + 1 }
        let daysText: String
        if days.count == 7 {
            daysText = String(localized: "Every day")
        } else if isContiguous, let start = days.first, let end = days.last {
            daysText = "\(weekday(start, short: true))–\(weekday(end, short: true))"
        } else if days.count <= 3 {
            daysText = days.map { weekday($0, short: true) }.formatted(.list(type: .and, width: .narrow))
        } else {
            daysText = String(localized: "\(days.count) days")
        }
        return "\(daysText) · \(timeRange(from: first.fromMinutes, to: first.toMinutes))"
    }
}
