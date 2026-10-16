import SwiftUI

extension View {
    /// Injects fresh instances of every app-wide model so previews render in isolation.
    func previewEnvironment() -> some View {
        let notifications = NotificationService()
        let lists = ListsModel(notifications: notifications)
        return self
            .environment(notifications)
            .environment(lists)
            .environment(ForeverStore())
            .environment(PartnerStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
            .environment(SubscriptionStore())
            .environment(AccountStore())
            .environment(ScreenTimeAuthorization())
    }
}
