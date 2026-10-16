import Foundation
import Observation
import os
import StoreKit

/// StoreKit 2 auto-renewable subscriptions. Premium is derived from verified, unrevoked
/// transactions only — never from a local flag the user could flip.
@Observable
final class SubscriptionStore {
    /// Must match the products configured in App Store Connect (and Products.storekit for local testing).
    enum ProductID {
        static let monthly = "app.samla.premium.monthly"
        static let yearly = "app.samla.premium.yearly"
        static let all = [monthly, yearly]
    }

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var loadError: String?

    var isPremium: Bool { !purchasedProductIDs.isEmpty }

    /// Premium features are unlocked for everyone while subscriptions are disabled.
    var hasPremiumAccess: Bool { !FeatureFlags.subscriptionsEnabled || isPremium }

    /// The currently active subscription transaction (used for refunds / management).
    private(set) var activeTransactionID: UInt64?

    private let logger = Logger(subsystem: "app.samla", category: "Store")
    private var updatesTask: Task<Void, Never>?

    init() {
        guard FeatureFlags.subscriptionsEnabled else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refreshEntitlements() }
    }

    func loadProducts() async {
        guard FeatureFlags.subscriptionsEnabled, products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: ProductID.all).sorted { $0.price < $1.price }
            loadError = nil
        } catch {
            logger.error("Product load failed: \(error.localizedDescription)")
            loadError = error.localizedDescription
        }
    }

    /// Returns `true` when the purchase completed and premium is unlocked.
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            await handle(verification)
            return isPremium
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        guard FeatureFlags.subscriptionsEnabled else { return }
        var purchased = Set<String>()
        var activeID: UInt64?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productType == .autoRenewable,
                  transaction.revocationDate == nil else { continue }
            purchased.insert(transaction.productID)
            activeID = transaction.id
        }
        purchasedProductIDs = purchased
        activeTransactionID = activeID
    }

    func isEligibleForIntroOffer(_ product: Product) async -> Bool {
        await product.subscription?.isEligibleForIntroOffer ?? false
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            logger.warning("Ignoring unverified transaction")
            return
        }
        await transaction.finish()
        await refreshEntitlements()
    }
}
