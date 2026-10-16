import SwiftUI

/// First launch, in the agreed order: the idea → Screen Time → Block Forever (skippable) → notifications.
struct OnboardingView: View {
    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(NotificationService.self) private var notifications
    @Environment(ForeverStore.self) private var forever
    @Environment(ListsModel.self) private var lists
    @AppStorage(StorageKey.onboardingCompleted) private var onboardingCompleted = false

    @State private var page = 0
    @State private var showForeverSetup = false

    var body: some View {
        TabView(selection: $page) {
            OnboardingPage(
                systemImage: "shield.lefthalf.filled",
                title: "Welcome to Samla",
                message: "Block the apps and websites that steal your time, and protect yourself for good."
            ) {
                Button("Get Started") { next() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .tag(0)

            OnboardingPage(
                systemImage: "hourglass",
                title: "Allow Screen Time",
                message: "Samla uses Apple's Screen Time to block apps and websites. Everything stays on your device."
            ) {
                Button(screenTime.isApproved ? "Continue" : "Allow Screen Time") {
                    Task {
                        if !screenTime.isApproved, await screenTime.request() {
                            lists.refreshSystemState()
                        }
                        next()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .tag(1)

            OnboardingPage(
                systemImage: "lock.shield.fill",
                title: "Block Forever",
                message: "“Tell the believing men to lower their gaze.” Porn, gambling and dating — blocked for good, free forever."
            ) {
                if forever.isActive() {
                    Button("Continue") { next() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Turn On") { showForeverSetup = true }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Skip") { next() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .tag(2)

            OnboardingPage(
                systemImage: "bell.badge.fill",
                title: "Stay on Track",
                message: "Get notified when a list starts or ends, and a minute before a break is over."
            ) {
                Button("Enable Notifications") {
                    Task {
                        await notifications.request()
                        lists.refreshSystemState()
                        onboardingCompleted = true
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Not Now") { onboardingCompleted = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(AppColors.background)
        .sheet(isPresented: $showForeverSetup) {
            ForeverSetupView { next() }
        }
    }

    private func next() {
        withAnimation { page = min(page + 1, 3) }
    }
}

/// Big icon, title, one sentence, buttons — like setting up an Apple device.
private struct OnboardingPage<Actions: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 72))
                .foregroundStyle(AppColors.primary)
                .frame(height: 96)
            VStack(spacing: 12) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColors.primary)
                Text(message)
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                actions
            }
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingView()
        .previewEnvironment()
}
