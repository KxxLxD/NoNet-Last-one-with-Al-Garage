import SwiftUI

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        // Isolated left-to-right so Arabic doesn't flip it to "(1) 1.0".
        return "\u{2066}\(short) (\(build))\u{2069}"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: Spacing.m) {
                    BrandLogo(size: 80)
                    Text("Samla")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                    Text("Samla helps you block the apps and websites that steal your time, and protect yourself from harmful content — calmly, privately, and on your own terms.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("Version", value: version)
                if let url = AppLinks.privacyPolicy {
                    Link("Full Privacy Policy", destination: url)
                }
                if let support = AppLinks.supportPage {
                    Link("Contact Support", destination: support)
                }
            } footer: {
                Text("Everything stays on your device. We collect no data.")
            }
        }
        .navigationTitle("About Samla")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AboutView() }
}
