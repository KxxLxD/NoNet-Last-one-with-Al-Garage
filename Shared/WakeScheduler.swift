import DeviceActivity
import Foundation
import os

/// Registers DeviceActivity schedules so the monitor extension wakes at every moment
/// shields need to change (slot starts/ends, session ends, break ends).
///
/// Each wake is a short interval (just above the system's 15-minute minimum) that *starts*
/// at the boundary; the extension re-evaluates all lists on `intervalDidStart`, so timing
/// stays exact no matter how short the session, slot or break is.
enum WakeScheduler {
    private static let logger = Logger(subsystem: "com.databox.nonet", category: "WakeScheduler")
    /// DeviceActivityCenter refuses more than 20 monitored activities.
    private static let maxActivities = 20
    private static let wakeLength = 16

    private struct MinuteOfWeek: Hashable {
        let day: Int // 0 = Sunday
        let minute: Int
    }

    static func reschedule(_ lists: [BlockList], forever: ForeverBlock = ForeverBlockRepository.load(), now: Date = .now) {
        let center = DeviceActivityCenter()
        center.stopMonitoring()

        var oneOff = Set<Date>()
        var weekly = Set<MinuteOfWeek>()

        // Lift Block Forever exactly when its 360-day wait ends, even if Samla isn't opened.
        if forever.isActive(at: now), let unlockDate = forever.unlockDate {
            oneOff.insert(unlockDate)
        }

        for list in lists {
            if let session = list.session, session.end > now { oneOff.insert(session.end) }
            if let breakUntil = list.breakUntil, breakUntil > now { oneOff.insert(breakUntil) }
            guard list.kind == .scheduled else { continue }
            for slot in list.slots {
                weekly.insert(MinuteOfWeek(day: slot.day, minute: slot.fromMinutes))
                let endDay = slot.isOvernight ? (slot.day + 1) % 7 : slot.day
                weekly.insert(MinuteOfWeek(day: endDay, minute: slot.toMinutes % (24 * 60)))
            }
        }

        // Boundaries that occur every day collapse into a single daily schedule.
        let minutes = Set(weekly.map(\.minute))
        let daily = minutes.filter { minute in (0..<7).allSatisfy { weekly.contains(MinuteOfWeek(day: $0, minute: minute)) } }
        let weeklyOnly = weekly.filter { !daily.contains($0.minute) }

        var activities: [(DeviceActivityName, DeviceActivitySchedule)] = []
        for date in oneOff.sorted() {
            activities.append((DeviceActivityName("wake.once.\(Int(date.timeIntervalSince1970))"), oneOffSchedule(at: date)))
        }
        for minute in daily.sorted() {
            activities.append((DeviceActivityName("wake.daily.\(minute)"), repeatingSchedule(day: nil, minute: minute)))
        }
        for time in weeklyOnly.sorted(by: { ($0.day, $0.minute) < ($1.day, $1.minute) }) {
            activities.append((DeviceActivityName("wake.weekly.\(time.day).\(time.minute)"), repeatingSchedule(day: time.day, minute: time.minute)))
        }

        if activities.count > maxActivities {
            logger.warning("Too many schedule boundaries (\(activities.count)); only the first \(maxActivities) are monitored.")
        }

        for (name, schedule) in activities.prefix(maxActivities) {
            do {
                try center.startMonitoring(name, during: schedule)
            } catch {
                logger.error("Failed to monitor \(name.rawValue): \(error.localizedDescription)")
            }
        }
    }

    static func stopAll() {
        DeviceActivityCenter().stopMonitoring()
    }

    private static func oneOffSchedule(at date: Date) -> DeviceActivitySchedule {
        let calendar = Calendar.current
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let end = date.addingTimeInterval(TimeInterval(wakeLength * 60))
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: date),
            intervalEnd: calendar.dateComponents(fields, from: end),
            repeats: false
        )
    }

    private static func repeatingSchedule(day: Int?, minute: Int) -> DeviceActivitySchedule {
        let endTotal = minute + wakeLength
        let endMinute = endTotal % (24 * 60)
        var start = DateComponents(hour: minute / 60, minute: minute % 60)
        var end = DateComponents(hour: endMinute / 60, minute: endMinute % 60)
        if let day {
            start.weekday = day + 1
            end.weekday = (endTotal >= 24 * 60 ? (day + 1) % 7 : day) + 1
        }
        return DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
    }
}
