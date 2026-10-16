import Foundation
import UserNotifications

/// "Break ends in a minute". Shared so breaks started from the block screen
/// (shield-action extension) get the same heads-up as breaks started in the app.
enum BreakReminder {
    static func request(for list: BlockList, now: Date = .now) -> UNNotificationRequest? {
        guard let breakUntil = list.breakUntil, breakUntil > now else { return nil }
        let warning = max(now.addingTimeInterval(1), breakUntil.addingTimeInterval(-60))

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Break ends in a minute")
        content.body = String(localized: "“\(list.name)” starts blocking again soon.")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: warning.timeIntervalSince(now), repeats: false)
        return UNNotificationRequest(identifier: "break.\(list.id.uuidString)", content: content, trigger: trigger)
    }
}
