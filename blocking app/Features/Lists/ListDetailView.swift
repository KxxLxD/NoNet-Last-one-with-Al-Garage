import FamilyControls
import SwiftUI

/// A list's summary and actions. While a protected list is active:
/// Hard Mode disables stop/edit/delete; Partner asks for the partner's PIN first.
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
        .background(AppColors.background)
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
        let status = ListStatus(list, at: now)
        let isLocked = list.isLocked(at: now)
        let end = list.activeUntil(at: now)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(list.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(2)
                    StatusLine(status: status, detail: statusDetail(list, end: end, now: now))
                }

                VStack(spacing: 14) {
                    row("Blocked", value: blockedSummary(list))
                    Divider()
                    row("Time", value: timeSummary(list))
                    Divider()
                    HStack {
                        Text("Protection").foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Label(list.protection.title, systemImage: list.protection.systemImage)
                            .foregroundStyle(AppColors.text)
                    }
                    .font(.subheadline)
                    if list.allowsBreaks {
                        Divider()
                        row("Breaks", value: String(localized: "\(list.breaksRemaining(at: now)) of \(list.breaks.count) left"))
                    }
                }
                .card(padding: 16)

                actions(list, now: now, isLocked: isLocked, end: end)
            }
            .padding(20)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actions(_ list: BlockList, now: Date, isLocked: Bool, end: Date?) -> some View {
        let isActive = list.isActive(at: now)
        let hardLocked = isLocked && list.isHard
        let needsPartner = isLocked && list.isPartnerProtected

        VStack(spacing: 12) {
            if isActive && list.allowsBreaks {
                if list.isOnBreak(at: now) {
                    Button("End Break") { model.endBreak(list.id) }
                        .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button("Start a \(Formatters.duration(minutes: list.breaks.minutes)) Break") {
                        model.takeBreak(list.id)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(list.breaksRemaining(at: now) == 0)
                }
            }

            if list.kind == .now {
                if isActive {
                    Button("Stop") {
                        if needsPartner { pendingPartnerAction = .stop } else { model.stop(list.id) }
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: AppColors.danger))
                    .disabled(hardLocked)
                } else {
                    Button("Start") { model.start(list.id) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }

            if hardLocked, let end {
                Label("Hard Mode · unlocks \(Formatters.clock(end, now: now))", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            } else if needsPartner {
                Label("Protected by your partner", systemImage: "person.2.fill")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack(spacing: 24) {
                Button("Edit") {
                    if needsPartner { pendingPartnerAction = .edit } else { editorMode = .edit(list) }
                }
                Text("·").foregroundStyle(AppColors.textSecondary)
                Button("Delete", role: .destructive) {
                    if needsPartner { pendingPartnerAction = .delete } else { deleteApproved = false; confirmDelete = true }
                }
                .tint(AppColors.danger)
            }
            .font(.body.weight(.semibold))
            .disabled(hardLocked)
            .padding(.top, 4)
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

    // MARK: - Text

    private func statusDetail(_ list: BlockList, end: Date?, now: Date) -> String? {
        if list.isOnBreak(at: now), let until = list.breakUntil {
            return String(localized: "Until \(Formatters.clock(until, now: now))")
        }
        return end.map { String(localized: "Ends \(Formatters.clock($0, now: now))") }
    }

    private func blockedSummary(_ list: BlockList) -> String {
        var parts: [String] = []
        let apps = list.appCount + list.categoryCount
        if apps > 0 { parts.append(String(localized: "\(apps) apps")) }
        if list.websiteCount > 0 { parts.append(String(localized: "\(list.websiteCount) websites")) }
        if list.blockAdultContent { parts.append(String(localized: "Adult websites")) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func timeSummary(_ list: BlockList) -> String {
        switch list.kind {
        case .now: Formatters.duration(seconds: list.durationSeconds)
        case .scheduled: Formatters.scheduleSummary(list.slots)
        }
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
