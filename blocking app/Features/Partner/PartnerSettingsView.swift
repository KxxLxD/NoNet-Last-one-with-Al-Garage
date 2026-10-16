import SwiftUI

/// Settings › Accountability Partner: one partner (name + 4-digit PIN) for every protected list.
/// Changing or removing the partner needs the current PIN, so it can't be used to skip protection.
struct PartnerSettingsView: View {
    @Environment(PartnerStore.self) private var partner

    private enum PINAction: Identifiable {
        case change, remove
        var id: Self { self }
    }

    @State private var isEditing = false
    @State private var pendingAction: PINAction?
    @State private var confirmForgot = false

    var body: some View {
        Form {
            if partner.hasPartner && !isEditing {
                currentPartner
            } else {
                PartnerSetupForm {
                    isEditing = false
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Accountability Partner")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pendingAction) { action in
            PartnerPINSheet(title: action == .change ? "Change Partner" : "Remove Partner", subject: String(localized: "my partner settings")) {
                switch action {
                case .change: isEditing = true
                case .remove: partner.remove()
                }
            }
        }
        .alert("Forgot the PIN?", isPresented: $confirmForgot) {
            Button("Remove in \(PartnerStore.forgotWaitDays) Days", role: .destructive) { partner.requestForgotReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your partner will be removed after a \(PartnerStore.forgotWaitDays)-day wait. Block Forever isn't affected and keeps its own 360-day wait.")
        }
    }

    @ViewBuilder
    private var currentPartner: some View {
        Section {
            LabeledContent("Partner", value: partner.name ?? "")
            LabeledContent("PIN", value: "••••")
        } footer: {
            Text("Lists protected by your partner can only be stopped, edited or deleted with this PIN while they're active.")
        }

        Section {
            Button("Change Partner") { pendingAction = .change }
            Button("Remove Partner", role: .destructive) { pendingAction = .remove }
        } footer: {
            Text("Both need your partner's current PIN.")
        }

        Section {
            if let date = partner.forgotResetDate {
                LabeledContent("Partner removed on", value: date.formatted(date: .abbreviated, time: .shortened))
                Button("Cancel Request") { partner.cancelForgotReset() }
            } else {
                Button("Forgot PIN?") { confirmForgot = true }
            }
        }
    }
}

/// Name plus a PIN the partner types twice.
private struct PartnerSetupForm: View {
    var onSaved: () -> Void

    @Environment(PartnerStore.self) private var partner
    @State private var name = ""
    @State private var pin = ""
    @State private var confirmPIN = ""

    private var isValid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            && PartnerStore.isValidPIN(pin)
            && pin == confirmPIN
    }

    var body: some View {
        Section {
            Text("Ask someone you trust to be your partner. They type a 4-digit PIN that only they know. Lists protected by your partner can't be stopped without it.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }

        Section("Partner's Name") {
            TextField("e.g., Ahmed", text: $name)
                .textInputAutocapitalization(.words)
        }

        Section {
            pinField("PIN", text: $pin)
            pinField("Confirm PIN", text: $confirmPIN)
        } header: {
            Text("PIN — your partner types it")
        } footer: {
            if !confirmPIN.isEmpty && pin != confirmPIN {
                Text("The PINs don't match.")
            }
        }

        Section {
            Button("Save Partner") {
                partner.setPartner(name: name, pin: pin)
                onSaved()
            }
            .disabled(!isValid)
        }
    }

    private func pinField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .onChange(of: text.wrappedValue) { _, value in
                text.wrappedValue = String(value.filter(\.isNumber).prefix(PartnerStore.pinLength))
            }
    }
}

#Preview {
    NavigationStack { PartnerSettingsView() }
        .previewEnvironment()
}
