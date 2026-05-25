import SwiftUI
import StoreKit

/// Premium upgrade / paywall surface.
///
/// Structure (top → bottom):
///   1. Hero band (logo + value prop) — replaces the clinical
///      "الاشتراك المميز" header that opened the old version.
///   2. Trial status banner (only when a 7-day trial is active) — was
///      tracked in state but never displayed.
///   3. Plan selector (two cards) — whole card is tappable (was only
///      the small "Select" button); yearly carries a BEST VALUE badge
///      with computed savings vs. monthly × 12.
///   4. Features list — ONE list (was duplicated as Free-vs-Premium
///      comparison + a second standalone Premium list).
///   5. Golden Guarantee callout.
///   6. Footer actions: Redeem code + Restore purchases (were
///      scattered through the page).
///
/// Sticky CTA at the bottom shows the selected plan's price; the
/// disabled state uses 0.4 opacity instead of looking identical to
/// the enabled state.
///
/// "You're already subscribed" state added so a Premium user opening
/// the page sees a confirmation surface instead of the upgrade flow.
struct UpgradeView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    @AppStorage(AppStorageKeys.trialStartTs) private var trialStartTs: Double = 0
    @StateObject private var store = StoreManager.shared

    @State private var selectedPlan: String? = "yearly" // default to yearly (best value)
    @State private var purchaseErrorMessage: String? = nil

    private var isArabic: Bool { lang.isArabicEffective }
    private let trialDuration: TimeInterval = 7 * 24 * 3600

    private var monthlyProduct: Product? { store.products.first { $0.id == ProductIDs.monthly } }
    private var yearlyProduct: Product? { store.products.first { $0.id == ProductIDs.yearly } }

    private var isTrialActive: Bool {
        guard trialStartTs > 0 else { return false }
        let start = Date(timeIntervalSince1970: trialStartTs)
        return Date().timeIntervalSince(start) < trialDuration
    }

    private var trialDaysRemaining: Int {
        guard isTrialActive else { return 0 }
        let start = Date(timeIntervalSince1970: trialStartTs)
        let remaining = trialDuration - Date().timeIntervalSince(start)
        return max(0, Int(ceil(remaining / 86_400)))
    }

    /// % savings on yearly vs. paying monthly for 12 months. Returns nil
    /// when either product hasn't loaded or the math doesn't yield a
    /// positive saving.
    private var yearlySavingsPercent: Int? {
        guard
            let m = monthlyProduct?.price,
            let y = yearlyProduct?.price,
            m > 0
        else { return nil }
        let twelveMonths = m * 12
        guard twelveMonths > y else { return nil }
        let percent = ((twelveMonths - y) / twelveMonths) * 100
        return Int(NSDecimalNumber(decimal: percent).doubleValue.rounded())
    }

    var body: some View {
        Group {
            if isPremium {
                subscribedState
            } else {
                paywall
            }
        }
        .background(AppColors.uiBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.uiBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await store.loadProducts() }
        .onChange(of: store.purchasedProductIDs) { ids in
            if !ids.isEmpty { isPremium = true }
        }
        .alert(
            isArabic ? "تعذّر الشراء" : "Purchase failed",
            isPresented: Binding(get: { purchaseErrorMessage != nil }, set: { if !$0 { purchaseErrorMessage = nil } })
        ) {
            Button(isArabic ? "حسناً" : "OK", role: .cancel) { purchaseErrorMessage = nil }
        } message: {
            Text(purchaseErrorMessage ?? "")
        }
    }

    // ─── Paywall (non-premium users) ──────────────────────────────

    @ViewBuilder
    private var paywall: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NNSpacing.lg) {
                heroBand
                if isTrialActive { trialBanner }
                planSelector
                featuresList
                goldenGuarantee
                footerActions
            }
            .padding(.horizontal, NNSpacing.xl)
            .padding(.top, NNSpacing.md)
            .padding(.bottom, NNSpacing.lg)
        }
        .safeAreaInset(edge: .bottom) { stickyCTA }
    }

    @ViewBuilder
    private var heroBand: some View {
        VStack(spacing: NNSpacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.infoBg)
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
            Text(isArabic ? "افتح كل الميزات" : "Unlock Everything")
                .font(.title.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text(isArabic ? "بلا حدود، بلا قيود — التزام أعمق وسيطرة أوضح." : "No limits, no friction — deeper commitment, clearer control.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NNSpacing.sm)
    }

    @ViewBuilder
    private var trialBanner: some View {
        HStack(spacing: NNSpacing.xs) {
            Image(systemName: "gift.fill")
                .foregroundColor(AppColors.accent)
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                Text(isArabic ? "تجربتك المجانية نشطة" : "Your free trial is active")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(isArabic
                    ? "متبقي \(trialDaysRemaining) يوم — جدّد لتستمر."
                    : "\(trialDaysRemaining) day\(trialDaysRemaining == 1 ? "" : "s") left — subscribe to keep going.")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(NNSpacing.sm)
        .background(AppColors.infoBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var planSelector: some View {
        VStack(spacing: NNSpacing.sm) {
            planCard(
                title: isArabic ? "سنوي" : "Yearly",
                product: yearlyProduct,
                planKey: "yearly",
                badge: bestValueBadge,
                isSelected: selectedPlan == "yearly"
            )
            planCard(
                title: isArabic ? "شهري" : "Monthly",
                product: monthlyProduct,
                planKey: "monthly",
                badge: nil,
                isSelected: selectedPlan == "monthly"
            )
        }
    }

    private var bestValueBadge: PlanBadge? {
        guard let percent = yearlySavingsPercent else {
            return PlanBadge(text: isArabic ? "الأفضل" : "BEST VALUE", color: AppColors.accent)
        }
        return PlanBadge(
            text: isArabic ? "وفّر \(percent)٪" : "SAVE \(percent)%",
            color: AppColors.accent
        )
    }

    private struct PlanBadge {
        let text: String
        let color: Color
    }

    @ViewBuilder
    private func planCard(title: String, product: Product?, planKey: String, badge: PlanBadge?, isSelected: Bool) -> some View {
        let radioIcon = isSelected ? "checkmark.circle.fill" : "circle"
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedPlan = planKey
        }) {
            HStack(alignment: .center, spacing: NNSpacing.sm) {
                Image(systemName: radioIcon)
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textDisabled)
                    .font(.title3)

                VStack(alignment: isArabic ? .trailing : .leading, spacing: 4) {
                    HStack(spacing: NNSpacing.xs) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        if let badge {
                            Text(badge.text)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badge.color)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let product {
                            Text(product.displayPrice)
                                .font(.title3.weight(.bold))
                                .foregroundColor(AppColors.accent)
                            if let period = product.subscription?.subscriptionPeriod {
                                Text("/ \(periodLabel(period))")
                                    .font(.footnote)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        } else {
                            Text(isArabic ? "جاري التحميل…" : "Loading…")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(NNSpacing.md)
            .background(isSelected ? AppColors.infoBg : AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.accent : AppColors.uiBorder,
                            lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(product == nil)
    }

    @ViewBuilder
    private var featuresList: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            Text(isArabic ? "ما الذي ستحصل عليه" : "What you get")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xs) {
                featureRow(icon: "infinity",   textAr: "قوائم حجب بلا حدود (3 مجاناً)", textEn: "Unlimited blocklists (3 on free)")
                featureRow(icon: "lock.shield", textAr: "الوضع الصارم بدون عدّ",        textEn: "Hard Mode without limits")
                featureRow(icon: "calendar",    textAr: "الجدولة الذكية",              textEn: "Smart scheduling")
                featureRow(icon: "cup.and.saucer", textAr: "جدولة الاستراحات",        textEn: "Planned breaks")
                featureRow(icon: "sparkles",    textAr: "مساعد NoNet الذكي",         textEn: "NoNet AI assistant")
                featureRow(icon: "person.badge.shield.checkmark", textAr: "دعم بأولوية", textEn: "Priority support")
            }
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.uiBorder, lineWidth: 0.5))
    }

    @ViewBuilder
    private func featureRow(icon: String, textAr: String, textEn: String) -> some View {
        HStack(alignment: .top, spacing: NNSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.successGreen)
                .font(.subheadline)
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .font(.subheadline)
            Text(isArabic ? textAr : textEn)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var goldenGuarantee: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xs) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkerboard")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.trophyGold)
                Text(isArabic ? "الضمان الذهبي" : "Golden Guarantee")
                    .font(.headline)
                    .foregroundColor(AppColors.trophyGold)
                Spacer(minLength: 0)
            }
            Text(isArabic ? "استرداد كامل بدون أسئلة." : "Full refund, no questions asked.")
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
            Text(isArabic
                ? "خلال 14 يوم للشهري، شهر واحد للسنوي. يُطلب الاسترداد من تطبيق App Store مباشرة."
                : "Within 14 days for monthly, 1 month for yearly. Refunds requested directly via the App Store.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(isArabic ? .trailing : .leading)
        }
        .padding(NNSpacing.md)
        .background(AppColors.trophyGold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.trophyGold.opacity(0.6), lineWidth: 0.8))
    }

    @ViewBuilder
    private var footerActions: some View {
        VStack(spacing: NNSpacing.xs) {
            Button(action: { Task { await store.presentRedeemSheet() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "ticket")
                    Text(isArabic ? "لديك كود؟ استرده" : "Have a code? Redeem")
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.accent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            Button(action: { Task { await store.restorePurchases() } }) {
                Text(isArabic ? "استعادة المشتريات" : "Restore Purchases")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, NNSpacing.sm)
    }

    @ViewBuilder
    private var stickyCTA: some View {
        VStack(spacing: NNSpacing.xs) {
            if selectedPlan == nil {
                Text(isArabic ? "اختر خطة للمتابعة" : "Select a plan to continue")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Button(action: { Task { await activatePremium() } }) {
                Text(ctaLabel)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canPurchase ? AppColors.accent : AppColors.textDisabled)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canPurchase)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, NNSpacing.md)
        .padding(.top, NNSpacing.xs)
        .padding(.bottom, NNSpacing.md)
        .background(
            AppColors.uiBackground
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: -2)
        )
    }

    private var canPurchase: Bool {
        selectedPlan != nil && store.state != .purchasing && selectedProduct != nil
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case "monthly": return monthlyProduct
        case "yearly": return yearlyProduct
        default: return nil
        }
    }

    private var ctaLabel: String {
        if store.state == .purchasing {
            return isArabic ? "جارٍ الشراء…" : "Purchasing…"
        }
        if let product = selectedProduct {
            // Show the plan price in the CTA so the user always sees what
            // they're committing to. Format: "اشترك بـ X / period" / "Subscribe X / period"
            let priceText = product.displayPrice
            let periodText: String
            if let period = product.subscription?.subscriptionPeriod {
                periodText = " / \(periodLabel(period))"
            } else {
                periodText = ""
            }
            return isArabic ? "اشترك بـ \(priceText)\(periodText)" : "Subscribe \(priceText)\(periodText)"
        }
        return isArabic ? "اختر خطة للمتابعة" : "Select a plan to continue"
    }

    private func activatePremium() async {
        guard let product = selectedProduct else {
            purchaseErrorMessage = isArabic
                ? "تعذّر تحميل الباقة من App Store. حاول لاحقاً."
                : "Couldn't load the plan from App Store. Please try again later."
            return
        }
        await store.purchase(product)
        // Capture the state synchronously after the await — `store.state`
        // is @Published and updates atomically, so reading once here is
        // race-free against future external transitions.
        if case .failed(let msg) = store.state {
            purchaseErrorMessage = msg
        } else if store.hasActiveSubscription {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }

    private func periodLabel(_ period: Product.SubscriptionPeriod) -> String {
        let unit: String = {
            switch period.unit {
            case .day: return isArabic ? "يوم" : "day"
            case .week: return isArabic ? "أسبوع" : "week"
            case .month: return isArabic ? "شهر" : "month"
            case .year: return isArabic ? "سنة" : "year"
            @unknown default: return ""
            }
        }()
        return period.value == 1 ? unit : "\(period.value) \(unit)"
    }

    // ─── Already-subscribed state ─────────────────────────────────

    @ViewBuilder
    private var subscribedState: some View {
        ScrollView {
            VStack(spacing: NNSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(AppColors.successGreen.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(AppColors.successGreen)
                }
                .padding(.top, NNSpacing.xl)

                Text(isArabic ? "أنت مشترك في Premium" : "You're a Premium subscriber")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(isArabic
                    ? "كل الميزات مفعَّلة. شكراً لدعمك لـ NoNet."
                    : "All features are unlocked. Thanks for supporting NoNet.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NNSpacing.xl)

                Spacer(minLength: NNSpacing.lg)

                VStack(spacing: NNSpacing.xs) {
                    Button(action: {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "creditcard.fill")
                            Text(isArabic ? "إدارة الاشتراك في App Store" : "Manage subscription in App Store")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button(action: { Task { await store.restorePurchases() } }) {
                        Text(isArabic ? "استعادة المشتريات" : "Restore Purchases")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, NNSpacing.xl)
                .padding(.bottom, NNSpacing.xl)
            }
        }
    }
}

#Preview {
    NavigationView { UpgradeView().environmentObject(LanguageManager.shared) }
}
