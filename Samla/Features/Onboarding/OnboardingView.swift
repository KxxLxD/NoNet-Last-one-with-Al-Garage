import SwiftUI

/// First launch in four steps: value → Screen Time (explained before Apple's prompt)
/// → Block Forever (optional) → notifications. No swiping, so the Screen Time step
/// can't be skipped by accident; a back button and a progress bar show where you are.
struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case welcome, screenTime, forever, notifications
    }

    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(NotificationService.self) private var notifications
    @Environment(ForeverStore.self) private var forever
    @Environment(ListsModel.self) private var lists
    @AppStorage(StorageKey.onboardingCompleted) private var onboardingCompleted = false

    @State private var step: Step = .welcome
    @State private var screenTimeDenied = false
    @State private var isRequesting = false
    @State private var showForeverSetup = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                content
                    .id(step)
                    .transition(.push(from: .trailing))
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
            actions
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
        .animation(.snappy, value: step)
        .animation(.snappy, value: screenTimeDenied)
        .sheet(isPresented: $showForeverSetup) {
            ForeverSetupView { advance() }
        }
        #if DEBUG
        // Screenshots/QA: launch with `-onboardingStep 2` to open a given step.
        .onAppear {
            let index = UserDefaults.standard.integer(forKey: "onboardingStep")
            if let debugStep = Step(rawValue: index) { step = debugStep }
        }
        #endif
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: Spacing.m) {
            Button {
                Haptics.tap()
                goBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(AppColors.primarySoft, in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.primary)
            .opacity(step == .welcome ? 0 : 1)
            .disabled(step == .welcome)
            .accessibilityLabel("Back")

            HStack(spacing: Spacing.xs) {
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? AppColors.primary : AppColors.border)
                        .frame(height: 4)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(progressText)

            Text(progressText)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize()
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
    }

    private var progressText: String {
        String(localized: "\(step.rawValue + 1) of \(Step.allCases.count)", locale: .app)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            StepContent(
                systemImage: "shield.lefthalf.filled",
                title: "Welcome to Samla",
                subtitle: "Take back your time, and protect yourself.",
                points: [
                    .init("hand.raised.fill", "Block distractions", "Choose apps and websites, and block them now or on a schedule."),
                    .init("checkmark.shield.fill", "Protect yourself for good", "Block Forever keeps porn, gambling and dating away."),
                    .init("lock.fill", "Private by design", "Everything stays on your device. We collect no data."),
                ]
            )
        case .screenTime:
            StepContent(
                systemImage: "hourglass",
                title: "Allow Screen Time",
                subtitle: "Apple will ask you to allow it next.",
                points: [
                    .init("app.badge.checkmark.fill", "Needed to block", "Apple only lets apps block other apps through Screen Time."),
                    .init("eye.slash.fill", "Samla can't see your activity", "Apple keeps the apps you choose private, even from Samla."),
                    .init("slider.horizontal.3", "You stay in control", "You can change it anytime in iOS Settings."),
                ]
            )
            if screenTimeDenied {
                Label("Without Screen Time, Samla can't block anything. You can allow it later from Home.", systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.scheduled)
                    .padding(Spacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.scheduled.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.control))
                    .padding(.top, Spacing.xl)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        case .forever:
            StepContent(
                systemImage: "lock.shield.fill",
                title: "Block Forever",
                subtitle: "“Tell the believing men to lower their gaze.” — An-Nur 24:30",
                points: [
                    .init("checkmark.shield.fill", "Porn, gambling and dating", "Blocked in every browser. Free forever."),
                    .init("trash.slash.fill", "Can't be deleted while on", "A real commitment for the weak moments."),
                    .init("hourglass", "Turning it off takes 360 days", "Or sooner with your accountability partner's PIN."),
                ]
            )
        case .notifications:
            StepContent(
                systemImage: "bell.badge.fill",
                title: "Stay on Track",
                subtitle: "A few helpful notifications, never spam.",
                points: [
                    .init("play.circle.fill", "When a list starts or ends", "So you always know what's blocked."),
                    .init("cup.and.saucer.fill", "A minute before a break ends", "Time to wrap up."),
                    .init("sun.max.fill", "One gentle daily reminder", "A verse, hadith or saying to keep you going."),
                ]
            )
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Spacing.m) {
            switch step {
            case .welcome:
                Button("Get Started", action: advance)
                    .buttonStyle(PrimaryButtonStyle())
            case .screenTime:
                if screenTime.isApproved {
                    Button("Continue", action: advance)
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(screenTimeDenied ? "Try Again" : "Continue") {
                        Task { await requestScreenTime() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isRequesting)
                    if screenTimeDenied {
                        Button("Continue Without It", action: advance)
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
            case .forever:
                if forever.isActive() {
                    Button("Continue", action: advance)
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Turn On") { showForeverSetup = true }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Skip for Now", action: advance)
                        .buttonStyle(SecondaryButtonStyle())
                }
            case .notifications:
                Button("Enable Notifications") {
                    Task {
                        await notifications.request()
                        lists.refreshSystemState()
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Not Now", action: finish)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func advance() {
        Haptics.tap()
        guard let next = Step(rawValue: step.rawValue + 1) else { return finish() }
        step = next
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        screenTimeDenied = false
        step = previous
    }

    private func requestScreenTime() async {
        isRequesting = true
        defer { isRequesting = false }
        if await screenTime.request() {
            Haptics.success()
            lists.refreshSystemState()
            screenTimeDenied = false
            advance()
        } else {
            Haptics.warning()
            screenTimeDenied = true
        }
    }

    private func finish() {
        Haptics.success()
        onboardingCompleted = true
    }
}

/// Big animated icon, title, subtitle and 2–3 benefit rows — like Apple's "What's New" screens.
private struct StepContent: View {
    struct Point: Identifiable {
        let systemImage: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        let id = UUID()

        init(_ systemImage: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) {
            self.systemImage = systemImage
            self.title = title
            self.detail = detail
        }
    }

    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let points: [Point]

    @State private var appeared = false

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            VStack(spacing: Spacing.l) {
                Image(systemName: systemImage)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 112, height: 112)
                    .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: 28))
                    .symbolEffect(.bounce, value: appeared)
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.s) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Spacing.xl) {
                ForEach(points) { point in
                    HStack(alignment: .top, spacing: Spacing.l) {
                        Image(systemName: point.systemImage)
                            .font(.title2)
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 36)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.title)
                                .font(.headline)
                                .foregroundStyle(AppColors.text)
                            Text(point.detail)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { appeared = true }
    }
}

#Preview {
    OnboardingView()
        .previewEnvironment()
}
