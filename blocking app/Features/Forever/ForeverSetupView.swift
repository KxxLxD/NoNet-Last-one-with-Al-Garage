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
            List {
                Section {
                    ForeverAyah()
                        .listRowBackground(Color.clear)
                }

                Section {
                    point("checkmark.shield.fill", "Blocks porn, gambling and dating websites in every browser.")
                    point("trash.slash.fill", "Samla can't be deleted from your phone while it's on.")
                    point("hourglass", "To turn it off, you ask and then wait \(ForeverBlock.unlockWaitDays) days. You can cancel the request anytime.")
                    point("person.2.fill", "Your accountability partner can turn it off sooner with their PIN.")
                    point("gift.fill", "Free forever.")
                }

                Section {
                    Toggle("Also lock all 17+ apps", isOn: $blocksMatureApps)
                } footer: {
                    Text("Hides and blocks every app rated 17+, which covers most dating and gambling apps. Some regular apps rated 17+ will be locked too.")
                }
            }
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
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
            }
            .alert("Screen Time access needed", isPresented: $showScreenTimeDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow Samla to use Screen Time so it can block content.")
            }
        }
    }

    private func point(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text).foregroundStyle(AppColors.text)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(AppColors.primary)
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
        VStack(spacing: Spacing.s) {
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
