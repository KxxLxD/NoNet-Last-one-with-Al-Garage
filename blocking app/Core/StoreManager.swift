//
//  StoreManager.swift
//  blocking app
//
//  StoreKit 2 subscription manager.
//
//  Requirements:
//  1. Products must be configured in App Store Connect with IDs from `ProductIDs`.
//  2. For local testing, add a `Products.storekit` file to the Xcode project with the same IDs
//     and configure the scheme to use it (Edit Scheme → Run → Options → StoreKit Configuration).
//
//  Promotional offers / discount codes are configured server-side in App Store Connect — do not
//  hard-code discount strings here; use the system Offer Code redemption sheet instead.
//

import Foundation
import StoreKit
import UIKit
import os

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case purchased
        case restored
        case failed(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var state: PurchaseState = .idle

    private let log = Logger(subsystem: "app.nonet.blocking", category: "Store")
    private var updateListenerTask: Task<Void, Never>?

    private init() {
        // Listen for transactions updates (renewals, refunds, family sharing, etc.)
        updateListenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }
    }

    deinit { updateListenerTask?.cancel() }

    /// Whether the user currently has any active subscription (controls `isPremium`).
    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }

    // MARK: - Loading

    func loadProducts() async {
        state = .loading
        do {
            let fetched = try await Product.products(for: ProductIDs.all)
            // Sort by price ascending so monthly appears before yearly when both fetched.
            self.products = fetched.sorted { $0.price < $1.price }
            await refreshEntitlements()
            state = .idle
        } catch {
            log.error("Load products failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }

    /// Re-scan current entitlements and update `purchasedProductIDs`.
    func refreshEntitlements() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.revocationDate == nil {
                active.insert(tx.productID)
            }
        }
        purchasedProductIDs = active
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        state = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    await refreshEntitlements()
                    state = .purchased
                } else {
                    state = .failed("Verification failed")
                }
            case .userCancelled:
                state = .idle
            case .pending:
                state = .idle
            @unknown default:
                state = .idle
            }
        } catch {
            log.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async {
        state = .loading
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            state = hasActiveSubscription ? .restored : .idle
        } catch {
            log.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }

    /// Present the App Store offer code redemption sheet. Use this instead of a hard-coded
    /// in-app discount string — Apple validates the code server-side.
    func presentRedeemSheet() async {
        do {
            try await AppStore.presentOfferCodeRedeemSheet(in: UIApplication.shared.activeWindowScene())
        } catch {
            log.error("Redeem sheet failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Private

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        if case .verified(let tx) = result {
            await tx.finish()
            await refreshEntitlements()
        }
    }
}

private extension UIApplication {
    func activeWindowScene() throws -> UIWindowScene {
        guard let scene = connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .first
        else {
            throw NSError(domain: "Store", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active window scene"])
        }
        return scene
    }
}
