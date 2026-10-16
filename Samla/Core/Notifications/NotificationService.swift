import Foundation
import Observation
import UserNotifications

/// Local notifications: scheduled lists starting and ending, sessions ending,
/// a heads-up one minute before a break ends, and one daily motivational reminder.
@Observable
final class NotificationService {
    private(set) var isAuthorized = false

    /// iOS keeps at most 64 pending notifications per app.
    private static let maxPending = 64
    private static let dailyReminderHour = 10

    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        await refresh()
    }

    /// Replaces every pending notification with the ones the current lists need.
    func reschedule(for lists: [BlockList], now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard isAuthorized else { return }

        var requests: [UNNotificationRequest] = [dailyReminder()]

        for list in lists {
            if let session = list.session, session.end > now {
                requests.append(oneOff(
                    id: "session.\(list.id.uuidString)",
                    title: String(localized: "Block ended 🎉"),
                    body: String(localized: "“\(list.name)” has ended. Great work!"),
                    at: session.end,
                    now: now
                ))
            }
            if let reminder = BreakReminder.request(for: list, now: now) {
                requests.append(reminder)
            }
            guard list.kind == .scheduled else { continue }
            for slot in list.slots {
                requests.append(weekly(
                    id: "slot.start.\(slot.id.uuidString)",
                    title: String(localized: "Block started"),
                    body: String(localized: "“\(list.name)” is now blocking."),
                    day: slot.day,
                    minute: slot.fromMinutes
                ))
                let endDay = slot.isOvernight ? (slot.day + 1) % 7 : slot.day
                requests.append(weekly(
                    id: "slot.end.\(slot.id.uuidString)",
                    title: String(localized: "Block ended 🎉"),
                    body: String(localized: "“\(list.name)” has ended. Great work!"),
                    day: endDay,
                    minute: slot.toMinutes % (24 * 60)
                ))
            }
        }

        for request in requests.prefix(Self.maxPending) {
            center.add(request)
        }
    }

    // MARK: - Builders

    private func dailyReminder() -> UNNotificationRequest {
        let content = makeContent(title: String(localized: "Samla"), body: MotivationalQuotes.random())
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: Self.dailyReminderHour), repeats: true)
        return UNNotificationRequest(identifier: "daily.reminder", content: content, trigger: trigger)
    }

    private func oneOff(id: String, title: String, body: String, at date: Date, now: Date) -> UNNotificationRequest {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSince(now)), repeats: false)
        return UNNotificationRequest(identifier: id, content: makeContent(title: title, body: body), trigger: trigger)
    }

    /// `day` is 0 = Sunday … 6 = Saturday.
    private func weekly(id: String, title: String, body: String, day: Int, minute: Int) -> UNNotificationRequest {
        let components = DateComponents(hour: minute / 60, minute: minute % 60, weekday: day + 1)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: id, content: makeContent(title: title, body: body), trigger: trigger)
    }

    private func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }
}
