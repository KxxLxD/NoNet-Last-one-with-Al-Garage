import SwiftUI

/// Block Forever once it's on: how long it has protected you, and the 360-day unlock request.
struct ForeverStatusView: View {
    @Environment(ForeverStore.self) private var forever
    @Environment(PartnerStore.self) private var partner
    @Environment(\.dismiss) private var dismiss

    @State private var confirmRequest = false
    @State private var showPartnerPIN = false
    // Skip the An-Nur verse: it is already shown in the header.
    @State private var quote = MotivationalQuotes.all.dropFirst().randomElement() ?? ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForeverAyah()

                if let days = forever.daysUntilUnlock() {
                    unlockRequested(days: days)
                } else {
                    protectedCard
                }
            }
            .padding(20)
        }
        .background(AppColors.background)
        .navigationTitle("Block Forever")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Request unlock?", isPresented: $confirmRequest) {
            Button("Start \(ForeverBlock.unlockWaitDays)-Day Wait", role: .destructive) { forever.requestUnlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Protection stays fully on during the wait. You can cancel the request anytime.")
        }
        .sheet(isPresented: $showPartnerPIN) {
            PartnerPINSheet(title: "Turn Off Block Forever", subject: String(localized: "Block Forever")) {
                forever.disable()
                dismiss()
            }
        }
    }

    private var protectedCard: some View {
        VStack(spacing: 16) {
            Label("Block Forever is on", systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundStyle(AppColors.active)
            if let since = forever.block.enabledAt {
                Text("Protecting you since \(since.formatted(date: .long, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            if forever.block.blocksMatureApps {
                Label("17+ apps are locked", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.text)
            }
            Button("Request Unlock") { confirmRequest = true }
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func unlockRequested(days: Int) -> some View {
        VStack(spacing: 16) {
            Text("\(days) days left")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppColors.primary)
            if let date = forever.block.unlockDate {
                Text("Unlocks on \(date.formatted(date: .long, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(quote)
                .font(.callout)
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)

            Button("Cancel Request") { forever.cancelUnlockRequest() }
                .buttonStyle(PrimaryButtonStyle())
            if partner.hasPartner {
                Button("Ask My Partner") { showPartnerPIN = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

#Preview {
    NavigationStack { ForeverStatusView() }
        .previewEnvironment()
}
