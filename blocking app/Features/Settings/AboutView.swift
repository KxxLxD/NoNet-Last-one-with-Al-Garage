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
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    BrandLogo(size: 88)
                    Text("Samla")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                    Text("Version \(version)")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Text("Samla helps you block the apps and websites that steal your time, and protect yourself from harmful content — calmly, privately, and on your own terms.")
                    .font(.body)
                    .foregroundStyle(AppColors.text)
                    .multilineTextAlignment(.center)
                    .card()

                VStack(spacing: 8) {
                    Text("Everything stays on your device. We collect no data.")
                    if let mail = AppLinks.supportMail {
                        Link(AppLinks.supportEmail, destination: mail)
                            .fontWeight(.semibold)
                    }
                }
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
            }
            .padding(24)
        }
        .background(AppColors.background)
        .navigationTitle("About Samla")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AboutView() }
}
