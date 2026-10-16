import StoreKit
import SwiftUI

/// Premium paywall backed by StoreKit 2. Prices, trials and currencies come from the App Store.
struct UpgradeView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID: String?
    @State private var introEligible: Set<String> = []
    @State private var isPurchasing = false
    @State private var showRedeem = false
    @State private var errorMessage: String?

    private var selectedProduct: Product? {
        store.products.first { $0.id == selectedID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if store.isPremium {
                    Label("Premium is active. Thank you!", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(AppColors.active)
                        .card(padding: 16)
                }

                plans
                FeatureComparison()
                footerLinks
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(AppColors.background)
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.isPremium { purchaseBar }
        }
        .offerCodeRedemption(isPresented: $showRedeem) { _ in
            Task { await store.refreshEntitlements() }
        }
        .alert("Purchase failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
        .task {
            await store.loadProducts()
            if selectedID == nil {
                selectedID = store.products.first { $0.id == SubscriptionStore.ProductID.yearly }?.id ?? store.products.first?.id
            }
            for product in store.products where await store.isEligibleForIntroOffer(product) {
                introEligible.insert(product.id)
            }
        }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unlock focus and change digital habits")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.text)
            Text("Everything you need to stay on track.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            VStack(spacing: 12) {
                if store.isLoadingProducts {
                    ProgressView()
                } else {
                    Text("Plans are unavailable right now. Check your connection and try again.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { Task { await store.loadProducts() } }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .card()
        } else {
            ForEach(store.products) { product in
                PlanCard(
                    product: product,
                    savingsPercent: savingsPercent(for: product),
                    showsTrial: introEligible.contains(product.id),
                    isSelected: product.id == selectedID
                ) {
                    selectedID = product.id
                }
            }
        }
    }

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
                Button("Redeem Code") { showRedeem = true }
            }
            .font(.subheadline.weight(.semibold))

            Text("Payment is charged to your Apple Account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings › Apple Account › Subscriptions.")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 16) {
                if let terms = AppLinks.termsOfUse {
                    Link("Terms of Use", destination: terms)
                }
                if let privacy = AppLinks.privacyPolicy {
                    Link("Privacy Policy", destination: privacy)
                } else {
                    NavigationLink("Privacy Policy") { PoliciesView() }
                }
            }
            .font(.caption.weight(.semibold))
        }
    }

    private var purchaseBar: some View {
        Button {
            Task { await purchase() }
        } label: {
            if isPurchasing {
                ProgressView().tint(.white)
            } else if let product = selectedProduct {
                Text(introEligible.contains(product.id) ? "Start Free Trial" : "Subscribe")
            } else {
                Text("Select a plan to continue")
            }
        }
        .buttonStyle(PrimaryButtonStyle(height: 50))
        .disabled(selectedProduct == nil || isPurchasing)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(AppColors.background)
    }

    // MARK: - Logic

    private func purchase() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await store.purchase(product) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Yearly savings compared with paying monthly for 12 months.
    private func savingsPercent(for product: Product) -> Int? {
        guard product.id == SubscriptionStore.ProductID.yearly,
              let monthly = store.products.first(where: { $0.id == SubscriptionStore.ProductID.monthly }) else { return nil }
        let fullYear = monthly.price * 12
        guard fullYear > 0, product.price < fullYear else { return nil }
        let ratio = (fullYear - product.price) / fullYear
        return Int((NSDecimalNumber(decimal: ratio).doubleValue * 100).rounded())
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let product: Product
    let savingsPercent: Int?
    let showsTrial: Bool
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    if let savingsPercent {
                        Badge(systemImage: nil, text: "Save \(savingsPercent)%")
                    }
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AppColors.primary : AppColors.textSecondary)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                        .foregroundStyle(AppColors.primary)
                    if let period = product.subscription?.subscriptionPeriod {
                        Text("/ \(PeriodFormatter.string(for: period))")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                if showsTrial, let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
                    Text("\(PeriodFormatter.string(for: offer.period)) free trial")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColors.active)
                }
                if !product.description.isEmpty {
                    Text(product.description)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? AppColors.primary : AppColors.border, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum PeriodFormatter {
    /// Localized "1 month", "7 days", "1 year"…
    static func string(for period: Product.SubscriptionPeriod) -> String {
        var components = DateComponents()
        switch period.unit {
        case .day: components.day = period.value
        case .week: components.weekOfMonth = period.value
        case .month: components.month = period.value
        case .year: components.year = period.value
        @unknown default: components.day = period.value
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        return formatter.string(from: components) ?? ""
    }
}

// MARK: - Free vs Premium

private struct FeatureComparison: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Free")
                .font(.headline)
                .foregroundStyle(AppColors.text)
            row("list.bullet", "Up to \(ListsModel.freeListLimit) block lists", available: true)
            row("lock.shield", "Hard Mode and partner protection", available: true)
            row("calendar", "Scheduling and breaks", available: true)
            row("checkmark.shield", "Block Forever", available: true)

            SoftDivider(verticalPadding: 4)

            Text("Premium")
                .font(.headline)
                .foregroundStyle(AppColors.text)
            row("infinity", "Unlimited lists", available: true)
            row("trophy", "Challenges with points and levels", available: true)
            row("square.stack", "Ready-made list templates", available: true)
            row("moon.stars", "Blocking during prayer times", available: true)
        }
        .card()
    }

    private func row(_ icon: String, _ text: LocalizedStringKey, available: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(available ? AppColors.primary : AppColors.textSecondary)
            Image(systemName: icon)
                .foregroundStyle(available ? AppColors.primary : AppColors.textSecondary)
                .frame(width: 22)
            Text(text)
                .foregroundStyle(available ? AppColors.text : AppColors.textSecondary)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack { UpgradeView() }
        .previewEnvironment()
}
