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

    var body: some View {
        Group {
            if let list = model.list(withID: listID) {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    content(list, now: context.date)
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

            Section("What to block") {
                LabeledContent("Apps", value: (list.appCount + list.categoryCount).formatted(.number.locale(.app)))
                LabeledContent("Websites", value: list.websiteCount.formatted(.number.locale(.app)))
                if list.blockAdultContent {
                    LabeledContent("Adult websites", value: String(localized: "Blocked"))
                }
            }

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
                if hardLocked, let end {
                    Text("Hard Mode · unlocks \(Formatters.clock(end, now: now))")
                } else if needsPartner {
                    Text("Protected by your partner")
                }
            }

            // Actions
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
                if list.kind == .now {
                    if isActive {
                        Button("Stop") {
                            if needsPartner { pendingPartnerAction = .stop } else { Haptics.warning(); model.stop(list.id) }
                        }
                        .disabled(hardLocked)
                    } else {
                        Button("Start") { Haptics.success(); model.start(list.id) }
                    }
                }
                Button("Delete List", role: .destructive) {
                    if needsPartner { pendingPartnerAction = .delete } else { deleteApproved = false; confirmDelete = true }
                }
                .disabled(hardLocked)
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
