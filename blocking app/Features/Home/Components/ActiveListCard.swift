import SwiftUI

/// Top of Home: the list blocking right now ("Sleep · Ends 6:00 AM"),
/// or a "Start Blocking" button when nothing is running.
struct ActiveListCard: View {
    @Environment(ListsModel.self) private var model
    let now: Date
    var onStart: () -> Void

    /// The active list that ends first.
    private var current: (list: BlockList, end: Date?)? {
        model.lists
            .filter { $0.isActive(at: now) }
            .map { ($0, $0.activeUntil(at: now)) }
            .min { ($0.1 ?? .distantFuture) < ($1.1 ?? .distantFuture) }
    }

    var body: some View {
        if let current {
            NavigationLink(value: current.list.id) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(current.list.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(1)
                    StatusLine(status: ListStatus(current.list, at: now), detail: detail(for: current.list, end: current.end))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .buttonStyle(.plain)
        } else if !model.lists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nothing is blocking right now")
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
                Button("Start Blocking", action: onStart)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func detail(for list: BlockList, end: Date?) -> String? {
        if list.isOnBreak(at: now), let until = list.breakUntil {
            return String(localized: "Until \(Formatters.clock(until, now: now))")
        }
        return end.map { String(localized: "Ends \(Formatters.clock($0, now: now))") }
    }
}
