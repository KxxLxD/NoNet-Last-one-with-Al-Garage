import SwiftUI

/// Settings in the style of iOS Settings: a header card with the Samla logo and account status,
/// then a few grouped sections with colored icon squares.
struct SettingsView: View {
    @Environment(PartnerStore.self) private var partner
    @Environment(AccountStore.self) private var account
    @Environment(ForeverStore.self) private var forever
    @Environment(\.openURL) private var openURL
    @State private var showForeverSetup = false

    var body: some View {
        NavigationStack {
            List {
                header

                Section {
                    navigationRow("Accountability Partner", systemImage: "person.2.fill", color: AppColors.primary, detail: partner.name ?? String(localized: "Not set")) {
                        PartnerSettingsView()
                    }
                    if forever.isActive() {
                        navigationRow("Block Forever", systemImage: "shield.lefthalf.filled", color: AppColors.secondary, detail: String(localized: "On")) {
                            ForeverStatusView()
                        }
                    } else {
                        Button { showForeverSetup = true } label: {
                            row("Block Forever", systemImage: "shield.lefthalf.filled", color: AppColors.secondary, detail: String(localized: "Off"), trailing: .chevron)
                        }
                    }
                    navigationRow("Tips", systemImage: "lightbulb.fill", color: AppColors.scheduled) {
                        TipsView()
                    }
                    navigationRow("Premium", systemImage: "sparkles", color: Color(hex: 0xC9A227), detail: String(localized: "Coming soon")) {
                        PremiumSoonView(reason: .browsing)
                    }
                }

                Section {
                    navigationRow("FAQ", systemImage: "questionmark", color: AppColors.active) {
                        FAQView()
                    }
                    if let support = AppLinks.supportPage {
                        linkRow("Contact Support", systemImage: "lifepreserver.fill", color: AppColors.active, url: support)
                    }
                    if let mail = AppLinks.supportMail {
                        linkRow("Support Email", systemImage: "envelope.fill", color: AppColors.active, url: mail)
                    }
                    // Shown once there's a link: a dead "Coming soon" row only lowers trust.
                    if let community = AppLinks.whatsAppCommunity ?? AppLinks.telegramChannel {
                        linkRow("Community", systemImage: "person.3.fill", color: AppColors.active, url: community)
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        row("Language", systemImage: "globe", color: AppColors.stopped, detail: currentLanguageName, trailing: .external)
                    }
                    navigationRow("Policies & Terms", systemImage: "doc.text.fill", color: AppColors.stopped) {
                        PoliciesView()
                    }
                    navigationRow("About Samla", systemImage: "info", color: AppColors.stopped) {
                        AboutView()
                    }
                }

                Section("Account") {
                    AccountSection()
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showForeverSetup) { ForeverSetupView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        Section {
            HStack(spacing: Spacing.l) {
                BrandLogo(size: 56)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.control))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control).stroke(AppColors.border, lineWidth: 0.5))
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(account.displayName ?? String(localized: "Samla"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                    // Partner status lives in its own row just below.
                    statusChip(account.isSignedIn ? "Signed in" : "No account", systemImage: account.isSignedIn ? "apple.logo" : "person.crop.circle")
                }
            }
            .padding(.vertical, Spacing.s)
        }
    }

    private func statusChip(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.background, in: Capsule())
    }

    // MARK: - Rows

    private var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    /// What sits at the trailing edge of a row that isn't a NavigationLink.
    private enum Trailing {
        case none
        /// Opens something inside Samla.
        case chevron
        /// Leaves Samla (iOS Settings, Safari, Mail).
        case external
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, color: Color, detail: String? = nil, trailing: Trailing = .none) -> some View {
        HStack(spacing: Spacing.m) {
            IconSquare(systemName: systemImage, color: color)
            Text(title).foregroundStyle(AppColors.text)
            Spacer()
            if let detail {
                Text(detail)
                    .foregroundStyle(AppColors.textSecondary)
            }
            if trailing != .none {
                Image(systemName: trailing == .external ? "arrow.up.forward" : "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.stopped)
                    .accessibilityHidden(true)
            }
        }
    }

    private func navigationRow<Destination: View>(_ title: LocalizedStringKey, systemImage: String, color: Color, detail: String? = nil, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            row(title, systemImage: systemImage, color: color, detail: detail)
        }
    }

    private func linkRow(_ title: LocalizedStringKey, systemImage: String, color: Color, url: URL) -> some View {
        Link(destination: url) {
            row(title, systemImage: systemImage, color: color, trailing: .external)
        }
    }
}

#Preview {
    SettingsView()
        .previewEnvironment()
}
