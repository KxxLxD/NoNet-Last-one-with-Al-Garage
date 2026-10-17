import FamilyControls
import SwiftUI

/// A list's page: a header with name and status, then Blocked / Time / Protection,
/// actions in a last section, and "Edit" in the navigation bar. While a protected list
/// is active, Hard Mode disables stop/edit/delete and Partner asks for the PIN first.
struct ListDetailView: View {
    @Environment(ListsModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let listID: UUID

    private enum PartnerAction: Identifiable {
        case stop, edit, delete
        var id: Self { self }
    }

    @State private var editorMode: ListEditorView.Mode?
    @State private var confirmDelete = false
    @State private var deleteApproved = false
    @State private var pendingPartnerAction: PartnerAction?
    @State private var pendingStart: BlockList?

    var body: some View {
        Group {
            if let list = model.list(withID: listID) {
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    content(list, now: .now)
                }
            } else {
                ContentUnavailableView("List not found", systemImage: "list.bullet.rectangle")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { editorMode != nil }, set: { if !$0 { editorMode = nil } })) {
            if let editorMode {
                ListEditorView(mode: editorMode)
            }
        }
        .sheet(item: $pendingPartnerAction) { action in
            PartnerPINSheet(title: "Partner PIN", subject: model.list(withID: listID)?.name ?? "") {
                perform(action)
            }
        }
        .confirmationDialog("Delete List", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.delete(listID, partnerApproved: deleteApproved)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this list?")
        }
        .startConfirmation(for: $pendingStart)
    }

    private func content(_ list: BlockList, now: Date) -> some View {
        let isActive = list.isActive(at: now)
        let isLocked = list.isLocked(at: now)
        let hardLocked = isLocked && list.isHard
        let needsPartner = isLocked && list.isPartnerProtected
        let end = list.activeUntil(at: now)

        return List {
            // Header
            Section {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(list.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(2)
                    if let countdownEnd = list.isOnBreak(at: now) ? list.breakUntil : end {
                        CountdownText(end: countdownEnd)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                    }
                    StatusLine(status: ListStatus(list, at: now), detail: ListText.detail(for: list, at: now))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.xs, bottom: 0, trailing: Spacing.xs))
            }

            primaryAction(list, isActive: isActive, hardLocked: hardLocked, needsPartner: needsPartner, end: end, now: now)

            BlockedItemsSection(list: list)

            Section("Time") {
                switch list.kind {
                case .now:
                    LabeledContent("Duration", value: Formatters.duration(seconds: list.durationSeconds))
                case .scheduled:
                    LabeledContent("Schedule", value: Formatters.scheduleSummary(list.slots))
                }
                if let end {
                    LabeledContent("Ends", value: Formatters.clock(end, now: now))
                }
                if list.allowsBreaks {
                    LabeledContent("Breaks", value: String(localized: "\(list.breaksRemaining(at: now)) of \(list.breaks.count) left", locale: .app))
                }
            }

            Section {
                Label(list.protection.title, systemImage: list.protection.systemImage)
            } header: {
                Text("Protection")
            } footer: {
                if needsPartner {
                    Text("Protected by your partner")
                }
            }

            // Secondary actions
            Section {
                if isActive && list.allowsBreaks {
                    if list.isOnBreak(at: now) {
                        Button("End Break") { Haptics.tap(); model.endBreak(list.id) }
                    } else {
                        Button("Start a \(Formatters.duration(minutes: list.breaks.minutes)) Break") {
                            Haptics.success()
                            model.takeBreak(list.id)
                        }
                        .disabled(list.breaksRemaining(at: now) == 0)
                    }
                }
                // While Hard Mode is locked the row above already explains; no dead buttons.
                if !hardLocked {
                    Button("Delete List", role: .destructive) {
                        if needsPartner { pendingPartnerAction = .delete } else { deleteApproved = false; confirmDelete = true }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    if needsPartner { pendingPartnerAction = .edit } else { editorMode = .edit(list) }
                }
                .disabled(hardLocked)
            }
        }
    }

    /// The one big action under the header: Start, Stop, Skip Today / Resume Now, or why it's locked.
    @ViewBuilder
    private func primaryAction(_ list: BlockList, isActive: Bool, hardLocked: Bool, needsPartner: Bool, end: Date?, now: Date) -> some View {
        if hardLocked, let end {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Locked until \(Formatters.clock(end, now: now))")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                        Text("Hard Mode can't be stopped, edited or deleted while it's active.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } icon: {
                    Image(systemName: "lock.fill").foregroundStyle(AppColors.primary)
                }
            }
        } else if list.kind == .scheduled && list.protection == .none && (isActive || list.isSkipped(at: now)) {
            Section {
                if list.isSkipped(at: now) {
                    Button {
                        Haptics.success()
                        model.resumeSchedule(list.id)
                    } label: {
                        Label("Resume Now", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button {
                        Haptics.warning()
                        model.skipToday(list.id)
                    } label: {
                        Label("Skip Today", systemImage: "forward.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } else if list.kind == .now {
            Section {
                if isActive {
                    Button {
                        if needsPartner { pendingPartnerAction = .stop } else { Haptics.warning(); model.stop(list.id) }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: AppColors.danger))
                } else {
                    Button {
                        if list.startNeedsConfirmation {
                            pendingStart = list
                        } else {
                            Haptics.success()
                            model.start(list.id)
                        }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private func perform(_ action: PartnerAction) {
        guard let list = model.list(withID: listID) else { return }
        switch action {
        case .stop: model.stop(list.id, partnerApproved: true)
        case .edit: editorMode = .edit(list, partnerApproved: true)
        case .delete:
            deleteApproved = true
            confirmDelete = true
        }
    }
}

/// "What to block" rows, shared by the list's page and the summary before saving.
struct BlockedItemsSection: View {
    let list: BlockList

    var body: some View {
        Section("What to block") {
            if list.blocksEverything {
                Label("No Internet Mode", systemImage: "wifi.slash")
                LabeledContent("Allowed Apps", value: list.allowedSelection.applicationTokens.count.formatted(.number.locale(.app)))
            } else {
                LabeledContent("Apps", value: (list.appCount + list.categoryCount).formatted(.number.locale(.app)))
                LabeledContent("Websites", value: list.websiteCount.formatted(.number.locale(.app)))
                if list.blockAdultContent {
                    LabeledContent("Adult websites", value: String(localized: "Blocked"))
                }
            }
        }
    }
}
