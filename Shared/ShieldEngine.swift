import FamilyControls
import Foundation
import ManagedSettings

/// Translates the active block lists and Block Forever into Screen Time restrictions.
///
/// Everything is merged into one named store so overlapping rules never conflict:
/// the store always reflects the union of everything that should be blocked right now.
enum ShieldEngine {
    private static let storeName = "samla.blocking"
    /// ManagedSettings caps shielded application tokens per store.
    private static let maxApplications = 50
    /// The web content filter accepts at most 50 domains.
    private static let maxFilterDomains = 50
    /// App Store rating 300 = 12+, so every 17+ app is hidden and can't be opened.
    private static let matureAppsRatingCap = 300

    static func apply(_ lists: [BlockList], forever: ForeverBlock = ForeverBlockRepository.load(), at date: Date = .now) {
        let store = ManagedSettingsStore(named: .init(storeName))
        let shielding = lists.filter { $0.isShielding(at: date) }
        let foreverActive = forever.isActive(at: date)

        guard !shielding.isEmpty || foreverActive else {
            store.clearAllSettings()
            return
        }

        var applications = Set<ApplicationToken>()
        var categories = Set<ActivityCategoryToken>()
        var webTokens = Set<WebDomainToken>()
        // Block Forever domains go first so they always fit under the filter cap.
        var domains: [String] = foreverActive ? ForeverBlock.blockedDomains : []
        var filtersAdultContent = foreverActive

        for list in shielding {
            applications.formUnion(list.selection.applicationTokens)
            categories.formUnion(list.selection.categoryTokens)
            webTokens.formUnion(list.selection.webDomainTokens)
            domains.append(contentsOf: list.websites)
            filtersAdultContent = filtersAdultContent || list.blockAdultContent
        }

        var seen = Set<String>()
        let filterDomains = Set(domains.filter { seen.insert($0).inserted }.prefix(maxFilterDomains).map { WebDomain(domain: $0) })

        store.shield.applications = applications.isEmpty ? nil : Set(applications.prefix(maxApplications))
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = webTokens.isEmpty ? nil : webTokens

        if filtersAdultContent {
            store.webContent.blockedByFilter = .auto(filterDomains)
        } else {
            store.webContent.blockedByFilter = filterDomains.isEmpty ? nil : .specific(filterDomains)
        }

        store.appStore.maximumRating = foreverActive && forever.blocksMatureApps ? matureAppsRatingCap : nil

        // Hard Mode, partner lists and Block Forever: Samla can't be uninstalled to escape the commitment.
        let hasLockedList = lists.contains { $0.isLocked(at: date) }
        store.application.denyAppRemoval = hasLockedList || foreverActive ? true : nil
    }

    static func clearAll() {
        ManagedSettingsStore(named: .init(storeName)).clearAllSettings()
    }
}
