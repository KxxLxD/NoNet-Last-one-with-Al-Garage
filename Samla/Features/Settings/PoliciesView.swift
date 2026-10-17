import SwiftUI

struct PoliciesView: View {
    private let privacy: [LocalizedStringKey] = [
        "Samla does not collect, store on servers, sell or share personal data. There are no analytics or advertising SDKs.",
        "Your block lists, schedules, partner details and settings are stored only on your device. Deleting the app or using Delete Account & Data in Settings removes them.",
        "Apps, categories and websites you choose are handled by Apple's Screen Time framework as private tokens; Samla cannot see which apps they are or how you use them.",
        "Your partner's PIN is stored only on this device, as a protected hash in the Keychain. It is never sent anywhere.",
        "If you use Sign in with Apple, Samla stores only the anonymous Apple user identifier and the name you choose to share, on this device.",
    ]

    var body: some View {
        List {
            Section {
                ForEach(privacy.indices, id: \.self) { index in
                    Text(privacy[index])
                        .font(.subheadline)
                        .foregroundStyle(AppColors.text)
                        .padding(.vertical, Spacing.xs)
                }
                if let url = AppLinks.privacyPolicy {
                    Link("Full Privacy Policy", destination: url)
                }
            } header: {
                Text("Privacy Policy").sectionCaption()
            }

            Section {
                Text("Samla is provided to help you build healthier digital habits. Hard Mode and Block Forever are voluntary commitments: once on, they can't be turned off early, so choose carefully.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.text)
                    .padding(.vertical, Spacing.xs)
                if let terms = AppLinks.termsOfUse {
                    Link("Apple Standard EULA", destination: terms)
                }
            } header: {
                Text("Terms of Use").sectionCaption()
            }

            if let email = AppLinks.supportEmail {
                Section {
                    Text("Questions? Contact \(email)")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .navigationTitle("Policies & Terms")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PoliciesView() }
}
