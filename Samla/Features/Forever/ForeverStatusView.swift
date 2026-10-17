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
        List {
            Section {
                ForeverAyah()
                    .listRowBackground(Color.clear)
            }

            if let days = forever.daysUntilUnlock() {
                Section {
                    VStack(spacing: Spacing.s) {
                        Text(String(localized: "\(days) days left", locale: .app))
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppColors.primary)
                        if let date = forever.block.unlockDate {
                            Text("Unlocks on \(date.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(.app)))")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.s)
                } footer: {
                    Text(quote)
                        .sectionCaption()
                }

                Section {
                    Button("Cancel Request") { forever.cancelUnlockRequest() }
                    if partner.hasPartner {
                        Button("Ask My Partner") { showPartnerPIN = true }
                    }
                }
            } else {
                Section {
                    Label {
                        Text("Block Forever is on")
                    } icon: {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(AppColors.active)
                    }
                    if let since = forever.block.enabledAt {
                        LabeledContent("Protecting you since", value: since.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(.app)))
                    }
                    if forever.block.blocksMatureApps {
                        Label("17+ apps are locked", systemImage: "lock.fill")
                    }
                }

                Section {
                    Button("Request Unlock", role: .destructive) { confirmRequest = true }
                } footer: {
                    Text("Protection stays fully on during the wait. You can cancel the request anytime.")
                        .sectionCaption()
                }
            }
        }
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
}

#Preview {
    NavigationStack { ForeverStatusView() }
        .previewEnvironment()
}
