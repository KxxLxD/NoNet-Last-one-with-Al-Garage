import SwiftUI

/// Routes between onboarding and the main app. Signing in is optional and lives in Settings › Account.
struct RootView: View {
    @AppStorage(StorageKey.onboardingCompleted) private var onboardingCompleted = false

    var body: some View {
        Group {
            if onboardingCompleted {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.default, value: onboardingCompleted)
    }
}

/// UserDefaults keys used with `@AppStorage`.
enum StorageKey {
    static let onboardingCompleted = "onboarding.completed"
    static let selectedTab = "app.selectedTab"
    /// The user tapped "Notify Me" on the Premium coming-soon page.
    static let premiumNotifyMe = "premium.notifyMe"
}
