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
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 52))
                        .foregroundStyle(AppColors.primary)
                    Text("Premium is coming soon")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                    if reason == .listLimit {
                        Text("The free version holds \(ListsModel.freeListLimit) lists. Premium will remove the limit.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 16) {
                    feature("infinity", "Unlimited lists")
                    feature("trophy.fill", "Challenges with points and levels")
                    feature("square.stack.fill", "Ready-made list templates")
                    feature("moon.stars.fill", "Blocking during prayer times")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                Text("Block Forever stays free forever.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    notifyMe = true
                } label: {
                    Label(notifyMe ? "We'll let you know" : "Notify Me", systemImage: notifyMe ? "checkmark" : "bell.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(notifyMe)
            }
            .padding(20)
        }
        .background(AppColors.background)
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
        .font(.body)
    }
}

#Preview {
    NavigationStack { PremiumSoonView(reason: .listLimit) }
}
