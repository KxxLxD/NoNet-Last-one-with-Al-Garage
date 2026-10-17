import SwiftUI

/// The Lists tab: Active, then Scheduled, then Stopped. "+" creates a list,
/// and unprotected lists can be swiped to delete.
struct ListsView: View {
    @Environment(ListsModel.self) private var model
    @Environment(SubscriptionStore.self) private var subscriptions

    @State private var showCreate = false
    @State private var showPremium = false
    @State private var pendingDelete: BlockList?
    @State private var pendingStart: BlockList?

    var body: some View {
        NavigationStack {
            // `.now`, not the tick's date: after a start or stop the tick date is stale for up to 30 s.
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                content(now: .now)
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createTapped) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create List")
                }
            }
            .navigationDestination(for: UUID.self) { ListDetailView(listID: $0) }
            .sheet(isPresented: $showCreate) { ListEditorView(mode: .create) }
            .sheet(isPresented: $showPremium) { NavigationStack { PremiumSoonView(reason: .listLimit) } }
            .confirmationDialog("Delete List", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let list = pendingDelete { model.delete(list.id) }
                }
            } message: {
                Text("Are you sure you want to delete this list?")
            }
            .startConfirmation(for: $pendingStart)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if model.lists.isEmpty {
            ContentUnavailableView {
                Label("Start your first block list", systemImage: "shield.lefthalf.filled")
            } description: {
                Text("Choose apps and websites, then block them now or on a schedule.")
            } actions: {
                Button("Create List", action: createTapped)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            }
        } else {
            let sorted = model.sorted(model.lists)
            List {
                section("Active", sorted.filter { $0.isActive(at: now) }, now: now)
                section("Scheduled", sorted.filter { !$0.isActive(at: now) && $0.kind == .scheduled }, now: now)
                section("Stopped", sorted.filter { !$0.isActive(at: now) && $0.kind == .now }, now: now)
                if !subscriptions.isPremium {
                    Section {} footer: {
                        Text(String(localized: "\(model.lists.count) of \(ListsModel.freeListLimit) free lists used", locale: .app))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, _ lists: [BlockList], now: Date) -> some View {
        if !lists.isEmpty {
            Section(title) {
                ForEach(lists) { list in
                    ListRow(list: list, now: now) { pendingStart = list }
                        .swipeActions(edge: .trailing) {
                            if !list.isLocked(at: now) {
                                Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = list }
                            }
                        }
                }
            }
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

/// "Sleep                 ▶"
/// "● Scheduled · Every day 10:00 PM–6:00 AM"
struct ListRow: View {
    @Environment(ListsModel.self) private var model
    let list: BlockList
    let now: Date
    /// Called instead of starting when the list is protected and needs confirming first.
    var onConfirmStart: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            NavigationLink(value: list.id) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Text(list.name)
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)
                        // While locked, the trailing lock already says so.
                        if list.protection != .none && !list.isLocked(at: now) {
                            Image(systemName: list.protection.systemImage)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .accessibilityLabel(list.protection.title)
                        }
                    }
                    // The section header already names the status, except "On break" inside Active.
                    let status = ListStatus(list, at: now)
                    StatusLine(status: status, detail: ListText.detail(for: list, at: now), showsTitle: status == .onBreak)
                }
                .padding(.vertical, Spacing.xs)
            }

            if list.isLocked(at: now) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityLabel("Locked")
            } else if list.kind == .now {
                let isActive = list.isActive(at: now)
                Button {
                    if isActive {
                        Haptics.warning()
                        model.stop(list.id)
                    } else if list.startNeedsConfirmation {
                        onConfirmStart()
                    } else {
                        Haptics.success()
                        model.start(list.id)
                    }
                } label: {
                    Image(systemName: isActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isActive ? AppColors.danger : AppColors.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isActive ? Text("Stop \(list.name)") : Text("Start \(list.name)"))
            }
        }
    }
}

/// Shared status details: "Ends 6:00 AM", "Until 6:05 AM", a schedule summary or a duration.
enum ListText {
    static func detail(for list: BlockList, at now: Date) -> String? {
        if list.isOnBreak(at: now), let until = list.breakUntil {
            return String(localized: "Until \(Formatters.clock(until, now: now))")
        }
        if let end = list.activeUntil(at: now) {
            return String(localized: "Ends \(Formatters.clock(end, now: now))")
        }
        switch list.kind {
        case .now: return Formatters.duration(seconds: list.durationSeconds)
        case .scheduled: return Formatters.scheduleSummary(list.slots)
        }
    }
}

#Preview {
    ListsView()
        .previewEnvironment()
}
