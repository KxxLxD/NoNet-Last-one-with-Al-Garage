import SwiftUI

/// Asks for the partner's PIN before a protected action. The partner types it in themselves;
/// "Ask My Partner" only opens WhatsApp with a ready message — the PIN is never sent.
struct PartnerPINSheet: View {
    let title: LocalizedStringKey
    /// What the user wants to unlock, used in the WhatsApp message.
    let subject: String
    var onSuccess: () -> Void

    @Environment(PartnerStore.self) private var partner
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var pin = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(AppColors.primary)
                    Text("Hand the phone to \(partner.name ?? String(localized: "your partner"))")
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                        .multilineTextAlignment(.center)
                    Text("Only your partner should type the PIN.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                SecureField("4-digit PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title2.monospacedDigit())
                    .focused($isFocused)
                    .inputFieldStyle()
                    .onChange(of: pin) { _, value in
                        pin = String(value.filter(\.isNumber).prefix(PartnerStore.pinLength))
                        errorMessage = nil
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppColors.danger)
                }

                VStack(spacing: 12) {
                    Button("Unlock", action: verify)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(pin.count != PartnerStore.pinLength)

                    if let url = whatsAppURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Ask My Partner", systemImage: "message.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(AppColors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private var whatsAppURL: URL? {
        AppLinks.whatsApp(message: String(localized: "Hi, I need you to enter your Samla PIN on my phone to unlock “\(subject)”. Can you help?"))
    }

    private func verify() {
        switch partner.verify(pin) {
        case .success:
            dismiss()
            onSuccess()
        case .wrong(let attemptsLeft):
            pin = ""
            errorMessage = String(localized: "Wrong PIN. \(attemptsLeft) attempts left.", locale: .app)
        case .lockedOut(let until):
            pin = ""
            errorMessage = String(localized: "Too many attempts. Try again at \(Formatters.clock(until)).")
        }
    }
}
