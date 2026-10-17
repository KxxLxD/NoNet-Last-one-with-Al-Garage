import SwiftUI

extension BlockList {
    /// Once running, Hard Mode can't be stopped and Partner needs the PIN, so starting a
    /// protected list is a commitment that must never come from a single stray tap.
    var startNeedsConfirmation: Bool { protection != .none }
}

extension View {
    /// Presents the start confirmation for `pending` and starts the list once confirmed.
    func startConfirmation(for pending: Binding<BlockList?>) -> some View {
        modifier(StartConfirmationModifier(pending: pending))
    }
}

private struct StartConfirmationModifier: ViewModifier {
    @Environment(ListsModel.self) private var model
    @Binding var pending: BlockList?

    func body(content: Content) -> some View {
        content.sheet(item: $pending) { list in
            StartConfirmationSheet(list: list) {
                Haptics.success()
                model.start(list.id)
            }
            .presentationDetents([.fraction(0.7), .large])
        }
    }
}

/// "Start List?" — what's locked, until when, and how, before a protected list starts.
private struct StartConfirmationSheet: View {
    let list: BlockList
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                List {
                    // The warning sits up top, where the confirm button can never cover it.
                    Section {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text(list.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppColors.primary)
                                .accessibilityAddTraits(.isHeader)
                            Text(list.isHard
                                 ? "While this list is active you won't be able to stop, edit or delete it, and Samla can't be deleted."
                                 : "While this list is active, only your partner's PIN can stop, edit or delete it, and Samla can't be deleted.")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    Section {
                        LabeledContent("Duration", value: Formatters.duration(seconds: list.durationSeconds))
                        LabeledContent("Ends", value: Formatters.clock(Date.now.addingTimeInterval(TimeInterval(list.durationSeconds))))
                        Label(list.protection.title, systemImage: list.protection.systemImage)
                    }
                }
            }
            .navigationTitle("Start List?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("I understand, start") {
                    dismiss()
                    onConfirm()
                }
                .buttonStyle(PrimaryButtonStyle(tint: AppColors.danger))
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
            }
        }
    }
}
