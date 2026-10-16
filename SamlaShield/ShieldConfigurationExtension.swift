import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The system block screen shown when a blocked app or website is opened:
/// white background, navy shield, the list's name and end time, a rotating
/// verse/hadith/saying, and "Start a Break" when the list still has breaks left.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private static let navy = UIColor(red: 15 / 255, green: 27 / 255, blue: 61 / 255, alpha: 1)
    private static let textSecondary = UIColor(red: 107 / 255, green: 114 / 255, blue: 128 / 255, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration { list in application.token.map { list.selection.applicationTokens.contains($0) } ?? false }
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration { list in
            let inApps = application.token.map { list.selection.applicationTokens.contains($0) } ?? false
            let inCategory = category.token.map { list.selection.categoryTokens.contains($0) } ?? false
            return inApps || inCategory
        }
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration(webDomain: webDomain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(webDomain: webDomain)
    }

    // MARK: - Building

    private func configuration(webDomain: WebDomain) -> ShieldConfiguration {
        configuration { list in
            let inTokens = webDomain.token.map { list.selection.webDomainTokens.contains($0) } ?? false
            let inSites = webDomain.domain.map { domain in list.websites.contains { domain.hasSuffix($0) } } ?? false
            return inTokens || inSites
        }
    }

    /// Picks the shielding list that blocks this item (or any shielding list), else Block Forever.
    private func configuration(matching blocks: (BlockList) -> Bool) -> ShieldConfiguration {
        let now = Date.now
        let shielding = BlockListRepository.load().filter { $0.isShielding(at: now) }
        let list = shielding.first(where: blocks) ?? shielding.first

        var title = String(localized: "Block Forever")
        var details: [String] = []
        if let list {
            title = list.name
            if let end = list.activeUntil(at: now) {
                details.append(String(localized: "Ends \(end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.app)))"))
            }
        }
        details.append(MotivationalQuotes.random())

        let breaksLeft = list?.breaksRemaining(at: now) ?? 0
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: .white,
            icon: UIImage(systemName: "shield.lefthalf.filled")?.withTintColor(Self.navy, renderingMode: .alwaysOriginal),
            title: .init(text: title, color: Self.navy),
            subtitle: .init(text: details.joined(separator: "\n\n"), color: Self.textSecondary),
            primaryButtonLabel: .init(text: String(localized: "Close"), color: .white),
            primaryButtonBackgroundColor: Self.navy,
            secondaryButtonLabel: breaksLeft > 0
                ? .init(text: String(localized: "Start a Break (\(breaksLeft) left)", locale: .app), color: Self.navy)
                : nil
        )
    }
}
