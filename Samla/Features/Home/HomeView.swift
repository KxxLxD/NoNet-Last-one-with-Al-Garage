import SwiftUI

/// Home is "what's happening now": a missing-permissions banner (only when needed), a filled navy
/// "now" card with a big countdown (or what starts next), quick-start buttons for your lists —
/// starter lists when there are none yet — and one Block Forever row. Managing lists lives in Lists.
struct HomeView: View {
    @Environment(ListsModel.self) private var model
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(ForeverStore.self) private var forever
    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showCreate = false
    @State private var showPremium = false
    @State private var showForeverSetup = false
    @State private var showPermissions = false
    @State private var pendingStarter: StarterList?
    @State private var pendingStart: BlockList?

    private var missingPermissions: Bool { !screenTime.isApproved || !notifications.isAuthorized }

    var body: some View {
        NavigationStack {
            // `.now`, not the tick's date: after a start or stop the tick date is stale for up to 30 s.
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                let now = Date.now
                List {
                    if missingPermissions { permissionsBanner }
                    nowCard(now: now)
                    quickStart(now: now)
                    foreverRow
                }
                .listSectionSpacing(.compact)
            }
            .navigationTitle("Samla")
            .navigationDestination(for: UUID.self) { ListDetailView(listID: $0) }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .forever: ForeverStatusView()
                }
            }
            .sheet(isPresented: $showCreate) { ListEditorView(mode: .create) }
            .sheet(item: $pendingStarter) { ListEditorView(mode: .starter($0.makeList())) }
            .sheet(isPresented: $showPremium) { NavigationStack { PremiumSoonView(reason: .listLimit) } }
            .sheet(isPresented: $showForeverSetup) { ForeverSetupView() }
            .sheet(isPresented: $showPermissions) {
                PermissionsSheet()
                    .presentationDetents([.medium])
            }
            .startConfirmation(for: $pendingStart)
        }
    }

    // MARK: - Permissions banner

    private var permissionsBanner: some View {
        Section {
            Button {
                showPermissions = true
            } label: {
                // Stacked at accessibility sizes so the message never breaks mid-word.
                let isLarge = dynamicTypeSize.isAccessibilitySize
                let layout = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s)) : AnyLayout(HStackLayout(spacing: Spacing.m))
                layout {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.scheduled)
                        Text("Some permissions are missing")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.text)
                    }
                    if !isLarge { Spacer(minLength: 0) }
                    Text("Fix")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primary)
                }
            }
            .listRowBackground(AppColors.scheduled.opacity(0.12))
        }
    }

    // MARK: - Now card

    @ViewBuilder
    private func nowCard(now: Date) -> some View {
        let current = model.lists
            .filter { $0.isActive(at: now) }
            .min { ($0.activeUntil(at: now) ?? .distantFuture) < ($1.activeUntil(at: now) ?? .distantFuture) }

        Section {
            if let list = current {
                // A real link (so VoiceOver and keyboards see a button) with the system chevron
                // swapped for a white one: the grey default vanishes on navy.
                NavigationLink(value: list.id) {
                    HStack(spacing: Spacing.s) {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Label(list.isOnBreak(at: now) ? "On break" : "Blocking now", systemImage: list.isOnBreak(at: now) ? "cup.and.saucer.fill" : "shield.lefthalf.filled")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(list.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            if let end = list.isOnBreak(at: now) ? list.breakUntil : list.activeUntil(at: now) {
                                CountdownText(end: end)
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(ListText.detail(for: list, at: now) ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, Spacing.m)
                }
                .navigationLinkIndicatorVisibility(.hidden)
            } else {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Nothing is blocking right now")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .accessibilityAddTraits(.isHeader)
                        nextUp(now: now)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Button(action: startTapped) {
                        Label(startButtonTitle, systemImage: "play.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(AppColors.primary)
                            .background(.white, in: RoundedRectangle(cornerRadius: Radius.control))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, Spacing.m)
            }
        }
        .listRowBackground(AppColors.primary)
    }

    // MARK: - Quick start

    /// What starts next today, or a nudge when nothing is scheduled.
    private func nextUp(now: Date) -> Text {
        let next = model.lists
            .compactMap { list in list.nextStartToday(after: now).map { (list, $0) } }
            .min { $0.1 < $1.1 }
        if case let (list, start)? = next {
            return Text("Next: “\(list.name)” at \(Formatters.clock(start, now: now))")
        }
        return Text("Start a list and stay focused.")
    }

    @ViewBuilder
    private func quickStart(now: Date) -> some View {
        let startable = model.sorted(model.lists.filter { $0.kind == .now && !$0.isActive(at: now) })

        if model.lists.isEmpty {
            StarterListsSection(onPick: starterTapped, onCustom: createTapped)
        } else {
            Section {
                if dynamicTypeSize.isAccessibilitySize {
                    // Stacked at accessibility sizes: a horizontal row would push "New List" off screen.
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        quickStartChips(startable)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                    .listRowInsets(EdgeInsets())
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.s) {
                            quickStartChips(startable)
                        }
                        .padding(.horizontal, Spacing.l)
                        .padding(.vertical, Spacing.m)
                    }
                    .listRowInsets(EdgeInsets())
                }
            } header: {
                Text("Quick Start").sectionCaption()
            }
        }
    }

    @ViewBuilder
    private func quickStartChips(_ startable: [BlockList]) -> some View {
        // Stacked at accessibility sizes: full-width chips whose names wrap instead of truncating.
        let isLarge = dynamicTypeSize.isAccessibilitySize
        ForEach(startable) { list in
            Button {
                start(list)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Label(list.name, systemImage: list.startNeedsConfirmation ? list.protection.systemImage : "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(isLarge ? nil : 1)
                        .fixedSize(horizontal: false, vertical: isLarge)
                    Text(Formatters.duration(seconds: list.durationSeconds))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: isLarge ? .infinity : nil, alignment: .leading)
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
                .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: Radius.control))
            }
            .buttonStyle(.plain)
            // The lock is only visible: say the protection too.
            .accessibilityValue(list.protection == .none ? Text(verbatim: "") : Text(list.protection.title))
        }
        Button(action: createTapped) {
            Label("New List", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: isLarge ? .infinity : nil, minHeight: 52, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: Radius.control).stroke(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Block Forever

    private var foreverRow: some View {
        Section {
            if forever.isActive() {
                NavigationLink(value: HomeRoute.forever) {
                    foreverLabel(status: foreverDetail, color: AppColors.activeText)
                }
            } else {
                Button { showForeverSetup = true } label: {
                    HStack {
                        foreverLabel(status: String(localized: "Off"), color: AppColors.textSecondary)
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func foreverLabel(status: String, color: Color) -> some View {
        LabeledContent {
            Text(status).foregroundStyle(color)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block Forever").foregroundStyle(AppColors.text)
                    Text("Porn, gambling and dating")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } icon: {
                IconSquare(systemName: "shield.lefthalf.filled", color: AppColors.primary)
            }
        }
    }

    private var foreverDetail: String {
        if let days = forever.daysUntilUnlock() {
            return String(localized: "Unlocks in \(days) days", locale: .app)
        }
        return String(localized: "On")
    }

    // MARK: - Actions

    /// Names the list the big button starts, so it never starts something unexpected.
    private var startButtonTitle: LocalizedStringKey {
        if let list = model.quickStartList { return "Start “\(list.name)”" }
        return "Start Blocking"
    }

    /// Runs the last-used Block Now list, or opens the editor when there's none.
    private func startTapped() {
        if let list = model.quickStartList {
            start(list)
        } else {
            createTapped()
        }
    }

    /// Unprotected lists start right away; protected ones ask first.
    private func start(_ list: BlockList) {
        if list.startNeedsConfirmation {
            pendingStart = list
        } else {
            Haptics.success()
            model.start(list.id)
        }
    }

    private func starterTapped(_ starter: StarterList) {
        if model.canCreateList(isPremium: subscriptions.isPremium) {
            pendingStarter = starter
        } else {
            showPremium = true
        }
    }

    private func createTapped() {
        if model.canCreateList(isPremium: subscriptions.isPremium) {
            showCreate = true
        } else {
            showPremium = true
        }
    }
}

/// Screen Time and notification access, opened from the Home banner.
private struct PermissionsSheet: View {
    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(NotificationService.self) private var notifications
    @Environment(ListsModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Screen Time", detail: "Required to block apps and websites.", systemImage: "hourglass", isGranted: screenTime.isApproved, action: "Allow") {
                        Task { if await screenTime.request() { model.refreshSystemState() } }
                    }
                    row("Notifications", detail: "Get told when a list starts or ends.", systemImage: "bell.badge.fill", isGranted: notifications.isAuthorized, action: "Enable") {
                        Task {
                            await notifications.request()
                            model.refreshSystemState()
                        }
                    }
                }
            }
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String, isGranted: Bool, action: LocalizedStringKey, perform: @escaping () -> Void) -> some View {
        // At accessibility sizes the button moves under the text instead of squeezing it.
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s)) : AnyLayout(HStackLayout(spacing: Spacing.m))
        return layout {
            HStack(spacing: Spacing.m) {
                IconSquare(systemName: systemImage, color: isGranted ? AppColors.active : AppColors.scheduled)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            if !isLarge { Spacer(minLength: 0) }
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.active)
                    .accessibilityLabel("Allowed")
            } else {
                Button(action, action: perform)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            }
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
