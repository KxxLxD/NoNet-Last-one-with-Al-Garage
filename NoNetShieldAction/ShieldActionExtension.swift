import Foundation
import FamilyControls
import ManagedSettings
import UserNotifications

/// Handles the block screen buttons. "Close" closes the app; "Start a Break" starts one of
/// the list's remaining breaks, lifts the shields and schedules the wake that restores them.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action) { $0.selection.applicationTokens.contains(application) })
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action) { $0.selection.webDomainTokens.contains(webDomain) })
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action) { $0.selection.categoryTokens.contains(category) })
    }

    private func respond(to action: ShieldAction, matching blocks: (BlockList) -> Bool) -> ShieldActionResponse {
        guard action == .secondaryButtonPressed else { return .close }

        let now = Date.now
        var lists = BlockListRepository.load()
        let candidates = lists.indices.filter { lists[$0].isShielding(at: now) && lists[$0].breaksRemaining(at: now) > 0 }
        guard let index = candidates.first(where: { blocks(lists[$0]) }) ?? candidates.first else { return .close }

        lists[index].breakUntil = now.addingTimeInterval(TimeInterval(lists[index].breaks.minutes * 60))
        lists[index].breakStarts.append(now)
        BlockListRepository.save(lists)

        let forever = ForeverBlockRepository.load()
        ShieldEngine.apply(lists, forever: forever, at: now)
        WakeScheduler.reschedule(lists, forever: forever, now: now)
        if let reminder = BreakReminder.request(for: lists[index], now: now) {
            UNUserNotificationCenter.current().add(reminder)
        }
        // Redraw: with the shield lifted, the app opens normally.
        return .defer
    }
}
