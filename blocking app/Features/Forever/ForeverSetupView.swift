import SwiftUI

/// Explains Block Forever plainly, then turns it on with "I understand, turn on".
struct ForeverSetupView: View {
    var onDone: () -> Void = {}

    @Environment(ForeverStore.self) private var forever
    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(ListsModel.self) private var lists
    @Environment(\.dismiss) private var dismiss

    // Off by default: it also locks regular 17+ apps, so the user opts in knowingly.
    @State private var blocksMatureApps = false
    @State private var showScreenTimeDenied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForeverAyah()

                    VStack(alignment: .leading, spacing: 16) {
                        point("checkmark.shield.fill", "Blocks porn, gambling and dating websites in every browser.")
                        point("trash.slash.fill", "Samla can't be deleted from your phone while it's on.")
                        point("hourglass", "To turn it off, you ask and then wait \(ForeverBlock.unlockWaitDays) days. You can cancel the request anytime.")
                        point("person.2.fill", "Your accountability partner can turn it off sooner with their PIN.")
                        point("gift.fill", "Free forever.")
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $blocksMatureApps) {
                            Text("Also lock all 17+ apps")
                                .font(.headline)
                                .foregroundStyle(AppColors.text)
                        }
                        .tint(AppColors.primary)
                        Text("Hides and blocks every app rated 17+, which covers most dating and gambling apps. Some regular apps rated 17+ will be locked too.")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .card()
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle("Block Forever")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("I understand, turn on") {
                    Task { await turnOn() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AppColors.background)
            }
            .alert("Screen Time access needed", isPresented: $showScreenTimeDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow Samla to use Screen Time so it can block content.")
            }
        }
    }

    private func point(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func turnOn() async {
        if !screenTime.isApproved {
            guard await screenTime.request() else {
                showScreenTimeDenied = true
                return
            }
        }
        forever.enable(blocksMatureApps: blocksMatureApps)
        lists.refreshSystemState()
        dismiss()
        onDone()
    }
}

/// The verse shown with Block Forever.
struct ForeverAyah: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.primary)
            Text("“Tell the believing men to lower their gaze.”")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.primary)
                .multilineTextAlignment(.center)
            Text("An-Nur 24:30")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ForeverSetupView()
        .previewEnvironment()
}
