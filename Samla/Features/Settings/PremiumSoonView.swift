import SwiftUI

/// Premium isn't on sale yet. Shown from Settings, and when a 4th list is created.
/// "Notify Me" is saved on the device (no server); a later update can announce Premium in the app.
struct PremiumSoonView: View {
    enum Reason {
        case browsing
        case listLimit
    }

    let reason: Reason

    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKey.premiumNotifyMe) private var notifyMe = false

    var body: some View {
        List {
            Section {
                VStack(spacing: Spacing.m) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)
                    Text("Premium is coming soon")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityAddTraits(.isHeader)
                    if reason == .listLimit {
                        Text("The free version holds \(ListsModel.freeListLimit) lists. Premium will remove the limit — for now, delete a list you no longer use to make room.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                feature("infinity", "Unlimited lists")
                feature("trophy.fill", "Challenges with points and levels")
                feature("square.stack.fill", "Ready-made list templates")
                feature("moon.stars.fill", "Blocking during prayer times")
            } footer: {
                Text("Block Forever stays free forever.")
                    .sectionCaption()
            }

            Section {
                Button {
                    notifyMe = true
                } label: {
                    Label(notifyMe ? "We'll let you know" : "Notify Me", systemImage: notifyMe ? "checkmark" : "bell.fill")
                }
                .disabled(notifyMe)
            }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if reason == .listLimit {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func feature(_ systemImage: String, _ title: LocalizedStringKey) -> some View {
        Label {
            Text(title).foregroundStyle(AppColors.text)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(AppColors.primary)
        }
    }
}

#Preview {
    NavigationStack { PremiumSoonView(reason: .listLimit) }
}
