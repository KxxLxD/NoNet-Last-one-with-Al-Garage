import SwiftUI

/// "Your Lists": active lists first, then the rest. Refreshes every 30 seconds so
/// statuses stay accurate without manual reloads.
struct ListsSection: View {
    @Environment(ListsModel.self) private var model
    var onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Lists")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
                Spacer()
                if !model.lists.isEmpty {
                    Button(action: onCreate) {
                        IconTile(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create List")
                }
            }

            if model.lists.isEmpty {
                EmptyListsView(onCreate: onCreate)
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    listsCard(now: context.date)
                }
            }
        }
    }

    private func listsCard(now: Date) -> some View {
        let active = model.sorted(model.lists.filter { $0.isActive(at: now) })
        let inactive = model.sorted(model.lists.filter { !$0.isActive(at: now) })
        let ordered = active + inactive

        return VStack(spacing: 0) {
            ForEach(ordered) { list in
                ListRow(list: list, now: now)
                    .padding(.horizontal, 16)
                if list.id != ordered.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 0.5))
    }
}

/// "Sleep            [▶]"
/// "● Scheduled · Every day 10:00 PM–6:00 AM"
private struct ListRow: View {
    @Environment(ListsModel.self) private var model
    let list: BlockList
    let now: Date

    private var isActive: Bool { list.isActive(at: now) }

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: list.id) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                    StatusLine(status: ListStatus(list, at: now), detail: detail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if list.isLocked(at: now) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .accessibilityLabel("Locked")
            } else if list.kind == .now {
                Button {
                    if isActive { model.stop(list.id) } else { model.start(list.id) }
                } label: {
                    IconTile(systemName: isActive ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isActive ? Text("Stop \(list.name)") : Text("Start \(list.name)"))
            }
        }
    }

    private var detail: String? {
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

/// First run: a big shield, "Start your first block list", and "Create List".
private struct EmptyListsView: View {
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.primary)
            Text("Start your first block list")
                .font(.headline)
                .foregroundStyle(AppColors.text)
            Button("Create List", action: onCreate)
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card()
    }
}
