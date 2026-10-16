import SwiftUI

struct PoliciesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                policyCard("Privacy Policy", body: [
                    "Samla does not collect, store on servers, sell or share personal data. There are no analytics or advertising SDKs.",
                    "Your block lists, schedules, partner details and settings are stored only on your device. Deleting the app or using Delete Account & Data in Settings removes them.",
                    "Apps, categories and websites you choose are handled by Apple's Screen Time framework as private tokens; Samla cannot see which apps they are or how you use them.",
                    "Your partner's PIN is stored only on this device, as a protected hash in the Keychain. It is never sent anywhere.",
                    "If you use Sign in with Apple, Samla stores only the anonymous Apple user identifier and the name you choose to share, on this device.",
                ])

                SoftDivider(verticalPadding: 0)

                policyCard("Terms of Use", body: [
                    "Samla is provided to help you build healthier digital habits. Hard Mode and Block Forever are voluntary commitments: once on, they can't be turned off early, so choose carefully.",
                ])

                if let terms = AppLinks.termsOfUse {
                    Link("Apple Standard EULA", destination: terms)
                        .font(.subheadline.weight(.semibold))
                }

                Text("Questions? Contact \(AppLinks.supportEmail)")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(24)
        }
        .background(AppColors.background)
        .navigationTitle("Policies & Terms")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policyCard(_ title: LocalizedStringKey, body paragraphs: [LocalizedStringKey]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.text)
            ForEach(paragraphs.indices, id: \.self) { index in
                Text(paragraphs[index])
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }
}

#Preview {
    NavigationStack { PoliciesView() }
}
