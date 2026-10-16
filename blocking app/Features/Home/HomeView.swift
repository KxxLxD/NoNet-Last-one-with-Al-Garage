import SwiftUI

/// Home is a summary, like the Health app: what's blocking now, Block Forever,
/// missing permissions, and what starts later today. Lists live in their own tab.
struct HomeView: View {
    @Environment(ListsModel.self) private var model
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(ForeverStore.self) private var forever
    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(NotificationService.self) private var notifications

    @State private var showCreate = false
    @State private var showPremium = false
    @State private var showForeverSetup = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                List {
                    nowSection(now: context.date)
                    foreverSection
                    permissionsSection
                    todaySection(now: context.date)
                }
            }
            .navigationTitle("Samla")
            .navigationDestination(for: UUID.self) { ListDetailView(listID: $0) }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .forever: ForeverStatusView()
                }
            }
            .sheet(isPresented: $showCreate) { ListEditorView(mode: .create) }
            .sheet(isPresented: $showPremium) { NavigationStack { PremiumSoonView(reason: .listLimit) } }
            .sheet(isPresented: $showForeverSetup) { ForeverSetupView() }
        }
    }

    // MARK: - Sections

    /// The active list that ends first, shown large; otherwise a "Start Blocking" button.
    @ViewBuilder
    private func nowSection(now: Date) -> some View {
        let current = model.lists
            .filter { $0.isActive(at: now) }
            .min { ($0.activeUntil(at: now) ?? .distantFuture) < ($1.activeUntil(at: now) ?? .distantFuture) }

        Section("Now") {
            if let list = current {
                NavigationLink(value: list.id) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(list.name)
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)
                        // Live countdown to the end of the block (or the break).
                        if let end = list.isOnBreak(at: now) ? list.breakUntil : list.activeUntil(at: now) {
                            CountdownText(end: end)
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.primary)
                        }
                        StatusLine(status: ListStatus(list, at: now), detail: ListText.detail(for: list, at: now))
                    }
                    .padding(.vertical, Spacing.s)
                }
            } else {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("Nothing is blocking right now")
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    Button("Start Blocking", action: startTapped)
                        .buttonStyle(PrimaryButtonStyle(height: 44))
                }
                .padding(.vertical, Spacing.s)
            }
        }
    }

    @ViewBuilder
    private var foreverSection: some View {
        Section {
            if forever.isActive() {
                NavigationLink(value: HomeRoute.forever) {
                    LabeledContent {
                        Text(foreverDetail)
                    } label: {
                        Label {
                            Text("Block Forever")
                        } icon: {
                            Image(systemName: "checkmark.shield.fill").foregroundStyle(AppColors.active)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Label {
                        Text("Block Forever").font(.headline)
                    } icon: {
                        Image(systemName: "shield.lefthalf.filled").foregroundStyle(AppColors.primary)
                    }
                    Text("“Tell the believing men to lower their gaze.”")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primary)
                    Text("Porn, gambling and dating — blocked for good. Free forever.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.vertical, Spacing.xs)
                Button("Turn On") { showForeverSetup = true }
            }
        }
    }

    @ViewBuilder
    private var permissionsSection: some View {
        if !screenTime.isApproved || !notifications.isAuthorized {
            Section {
                if !screenTime.isApproved {
                    permissionRow("Screen Time", detail: "Required to block apps and websites.", systemImage: "hourglass", action: "Allow") {
                        Task { if await screenTime.request() { model.refreshSystemState() } }
                    }
                }
                if !notifications.isAuthorized {
                    permissionRow("Notifications", detail: "Get told when a list starts or ends.", systemImage: "bell.badge.fill", action: "Enable") {
                        Task {
                            await notifications.request()
                            model.refreshSystemState()
                        }
                    }
                }
            } header: {
                Text("Permissions")
            }
        }
    }

    @ViewBuilder
    private func todaySection(now: Date) -> some View {
        let upcoming = model.lists
            .compactMap { list in list.nextStartToday(after: now).map { (list, $0) } }
            .sorted { $0.1 < $1.1 }

        Section("Later Today") {
            if upcoming.isEmpty {
                Text("Nothing else is scheduled today")
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(upcoming, id: \.0.id) { list, start in
                    NavigationLink(value: list.id) {
                        LabeledContent(list.name) {
                            Text("Starts \(Formatters.clock(start, now: now))")
                        }
                    }
                }
            }
        }
    }

    private func permissionRow(_ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String, action: LocalizedStringKey, perform: @escaping () -> Void) -> some View {
        HStack(spacing: Spacing.m) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } icon: {
                Image(systemName: systemImage).foregroundStyle(AppColors.scheduled)
            }
            Spacer()
            Button(action, action: perform)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
    }

    private var foreverDetail: String {
        if let days = forever.daysUntilUnlock() {
            return String(localized: "Unlocks in \(days) days", locale: .app)
        }
        return String(localized: "On")
    }

    // MARK: - Actions

    /// Runs the last-used Block Now list, or opens the editor when there's none.
    private func startTapped() {
        if let list = model.quickStartList {
            Haptics.success()
            model.start(list.id)
        } else if model.canCreateList(isPremium: subscriptions.isPremium) {
            showCreate = true
        } else {
            showPremium = true
        }
    }
}

enum HomeRoute: Hashable {
    case forever
}

#Preview {
    HomeView()
        .previewEnvironment()
}
