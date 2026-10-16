import SwiftUI

@main
struct SamlaApp: App {
    @State private var notifications: NotificationService
    @State private var lists: ListsModel
    @State private var forever: ForeverStore
    @State private var partner = PartnerStore()
    @State private var subscriptions = SubscriptionStore()
    @State private var account = AccountStore()
    @State private var screenTime = ScreenTimeAuthorization()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let notifications = NotificationService()
        let lists = ListsModel(notifications: notifications)
        _notifications = State(initialValue: notifications)
        _lists = State(initialValue: lists)
        _forever = State(initialValue: ForeverStore { lists.refreshSystemState() })
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(notifications)
                .environment(lists)
                .environment(forever)
                .environment(partner)
                .environment(subscriptions)
                .environment(account)
                .environment(screenTime)
                .tint(AppColors.primary)
                // Western digits everywhere, whatever the device region.
                .environment(\.locale, .app)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            screenTime.refresh()
            partner.resolveForgotReset()
            lists.reloadFromDisk()
            forever.refresh()
            Task {
                await notifications.refresh()
                // Re-sync shields: a schedule may have started or ended while we were away.
                lists.refreshSystemState()
                await account.verifyCredentialState()
                await subscriptions.refreshEntitlements()
            }
        }
    }
}
