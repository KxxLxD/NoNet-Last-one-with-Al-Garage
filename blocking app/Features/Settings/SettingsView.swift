import SwiftUI

/// Settings, in the agreed order: partner, tips, Premium (soon), help, community (soon),
/// language, policies, about, account.
struct SettingsView: View {
    @Environment(PartnerStore.self) private var partner
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PartnerSettingsView()
                    } label: {
                        row("Accountability Partner", systemImage: "person.2.fill", detail: partner.name ?? String(localized: "Not set"))
                    }
                    NavigationLink {
                        TipsView()
                    } label: {
                        row("Tips", systemImage: "lightbulb.fill")
                    }
                }

                Section {
                    NavigationLink {
                        PremiumSoonView(reason: .browsing)
                    } label: {
                        row("Premium", systemImage: "sparkles", detail: String(localized: "Coming soon"))
                    }
                }

                Section("Help & Support") {
                    if let mail = AppLinks.supportMail {
                        Link(destination: mail) {
                            row("Support Email", systemImage: "envelope.fill")
                        }
                    }
                    NavigationLink {
                        FAQView()
                    } label: {
                        row("FAQ", systemImage: "questionmark.circle.fill")
                    }
                }

                Section("Community") {
                    communityRow("WhatsApp Community", systemImage: "person.3.fill", url: AppLinks.whatsAppCommunity)
                    communityRow("Telegram Channel", systemImage: "paperplane.fill", url: AppLinks.telegramChannel)
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        row("Language", systemImage: "globe", detail: currentLanguageName)
                    }
                } footer: {
                    Text("iOS lets you pick Samla's language in Settings › Samla › Language.")
                }

                Section {
                    NavigationLink {
                        PoliciesView()
                    } label: {
                        row("Policies & Terms", systemImage: "doc.text.fill")
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        row("About Samla", systemImage: "info.circle.fill")
                    }
                }

                Section("Account") {
                    AccountSection()
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Settings")
        }
    }

    // MARK: - Building blocks

    private var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, detail: String? = nil) -> some View {
        HStack {
            Label {
                Text(title).foregroundStyle(AppColors.text)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(AppColors.primary)
            }
            Spacer()
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func communityRow(_ title: LocalizedStringKey, systemImage: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) { row(title, systemImage: systemImage) }
        } else {
            row(title, systemImage: systemImage, detail: String(localized: "Coming soon"))
        }
    }
}

#Preview {
    SettingsView()
        .previewEnvironment()
}
