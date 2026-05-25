import SwiftUI
import StoreKit

struct UpgradeView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    @AppStorage(AppStorageKeys.trialStartTs) private var trialStartTs: Double = 0
    @StateObject private var store = StoreManager.shared

    @State private var selectedPlan: String? = nil // "monthly" or "yearly"
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isArabic ? "الاشتراك المميز" : "Premium Pricing")
                    .font(.nnSectionTitle)

                Text(isArabic
                     ? "اشتراك يُدار عبر App Store. يمكنك إلغاء الاشتراك في أي وقت من إعدادات Apple."
                     : "Subscription managed via the App Store. Cancel anytime in your Apple Settings.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)

                // Plans (load asynchronously; placeholders show until products fetched)
                planCard(
                    title: isArabic ? "شهري" : "Monthly",
                    product: monthlyProduct,
                    planKey: "monthly",
                    isSelected: selectedPlan == "monthly",
                    onSelect: { selectedPlan = "monthly" }
                )

                planCard(
                    title: isArabic ? "سنوي" : "Yearly",
                    product: yearlyProduct,
                    planKey: "yearly",
                    isSelected: selectedPlan == "yearly",
                    onSelect: { selectedPlan = "yearly" }
                )

                // Redeem code (uses Apple's secure offer-code redemption — no hard-coded codes).
                Button(action: { Task { await store.presentRedeemSheet() } }) {
                    HStack {
                        Image(systemName: "ticket")
                        Text(isArabic ? "لديك كود؟ استرداده" : "Have a code? Redeem")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.infoBg)
                    .foregroundColor(AppColors.accent)
                    .cornerRadius(12)
                }

                featuresCard

                goldenGuaranteeCard

                Button(action: { Task { await store.restorePurchases() } }) {
                    Text(isArabic ? "استعادة المشتريات" : "Restore Purchases")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .background(AppColors.uiBackground)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: { Task { await activatePremium() } }) {
                    Text(ctaLabel)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(selectedPlan == nil || store.state == .purchasing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(AppColors.uiBackground)
        }
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

    private var ctaLabel: String {
        switch store.state {
        case .purchasing: return isArabic ? "جارٍ الشراء..." : "Purchasing..."
        default: break
        }
        if selectedPlan == "monthly" { return isArabic ? "ابدأ الشهرية الآن" : "Start Monthly" }
        if selectedPlan == "yearly" { return isArabic ? "ابدأ السنوية الآن" : "Start Yearly" }
        return isArabic ? "اختر خطة للمتابعة" : "Select a plan to continue"
    }

    private func activatePremium() async {
        let product: Product?
        switch selectedPlan {
        case "monthly": product = monthlyProduct
        case "yearly": product = yearlyProduct
        default: return
        }
        guard let product else {
            purchaseErrorMessage = isArabic
                ? "تعذّر تحميل الباقة من App Store. يرجى المحاولة لاحقاً."
                : "Couldn't load the plan from App Store. Please try again later."
            return
        }
        await store.purchase(product)
        if case .failed(let msg) = store.state {
            purchaseErrorMessage = msg
        } else if store.hasActiveSubscription {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }

    private func planCard(title: String, product: Product?, planKey: String, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.nnCardTitle)
                .foregroundColor(AppColors.textPrimary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let product {
                    Text(product.displayPrice)
                        .font(.title3).bold()
                        .foregroundColor(AppColors.accent)
                    if let period = product.subscription?.subscriptionPeriod {
                        Text("/ \(periodLabel(period))")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                } else {
                    Text(isArabic ? "جاري التحميل..." : "Loading...")
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            }
            HStack {
                Spacer()
                Button(action: onSelect) {
                    Text(isSelected ? (isArabic ? "محدد" : "Selected") : (isArabic ? "اختر" : "Select"))
                        .font(.subheadline.weight(.semibold))
                        .frame(height: 36)
                        .padding(.horizontal, 12)
                        .background(isSelected ? AppColors.infoBg : Color.clear)
                        .foregroundColor(AppColors.accent)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.accent, lineWidth: 1.5))
                        .cornerRadius(12)
                }
                .disabled(product == nil)
            }
        }
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? AppColors.accent : AppColors.uiBorder, lineWidth: isSelected ? 1 : 0.5)
        )
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

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isArabic ? "حرّر تركيزك وغيّر عاداتك الرقمية" : "Unlock focus and change digital habits")
                .font(.nnCardTitle)
                .foregroundColor(AppColors.textPrimary)
            Text(isArabic ? "كل ما تحتاجه لتبقى على المسار الصحيح." : "Everything you need to stay on track.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            SoftDivider(width: 300, opacity: 0.7)

            VStack(alignment: .leading, spacing: 8) {
                Text(isArabic ? "مجاني" : "Free")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                availabilityRow(icon: "list.bullet", textAr: "حتى 3 قوائم حجب", textEn: "Up to 3 blocklists", available: true)
                availabilityRow(icon: "lock.shield", textAr: "الوضع الصارم: 3 مرات فقط", textEn: "Hard Mode: 3 uses only", available: true)
                availabilityRow(icon: "calendar", textAr: "الجدولة الذكية", textEn: "Smart scheduling", available: false)
                availabilityRow(icon: "clock", textAr: "جدولة الاستراحات", textEn: "Planned breaks", available: false)
                availabilityRow(icon: "sparkles", textAr: "مساعد NoNet", textEn: "NoNet Assistant", available: false)
                availabilityRow(icon: "person.badge.shield.checkmark", textAr: "دعم أولوية", textEn: "Priority support", available: false)
            }

            SoftDivider(width: 300, opacity: 0.7)

            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "infinity", textAr: "قوائم بلا حدود", textEn: "Unlimited blocklists")
                featureRow(icon: "lock.shield", textAr: "الوضع الصارم", textEn: "Hard Mode")
                featureRow(icon: "calendar", textAr: "الجدولة الذكية", textEn: "Smart scheduling")
                featureRow(icon: "clock", textAr: "جدولة الاستراحات", textEn: "Planned breaks")
                featureRow(icon: "sparkles", textAr: "مساعد NoNet", textEn: "NoNet Assistant")
                featureRow(icon: "person.badge.shield.checkmark", textAr: "دعم أولوية", textEn: "Priority support")
                Text(isArabic ? "مزايا عملية تمنحك سيطرة هادئة ودائمة." : "Practical features that keep you calmly in control.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
    }

    private var goldenGuaranteeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkerboard")
                    .font(.nnSubheader.weight(.semibold))
                    .foregroundColor(AppColors.trophyGold)
                Text(isArabic ? "الضمان الذهبي" : "Golden Guarantee")
                    .font(.headline)
                    .foregroundColor(AppColors.trophyGold)
            }
            Text(isArabic ? "استرداد كامل للمبلغ بدون أسئلة." : "Full refund, no questions asked.")
                .foregroundColor(AppColors.textPrimary)
            Text(isArabic ? "الشهري: خلال 14 يوم — السنوي: خلال شهر واحد." : "Monthly: within 14 days — Yearly: within 1 month.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
            Text(isArabic
                 ? "الاسترداد يُطلب من Apple مباشرة من خلال تطبيق App Store."
                 : "Refunds are requested directly from Apple via the App Store.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .background(gold.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold, lineWidth: 1))
        .cornerRadius(16)
    }

    @ViewBuilder
    private func featureRow(icon: String, textAr: String, textEn: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
            Text(isArabic ? textAr : textEn)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)
        }
    }

    @ViewBuilder
    private func availabilityRow(icon: String, textAr: String, textEn: String, available: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(available ? AppColors.accent : AppColors.textSecondary)
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(available ? AppColors.accent : AppColors.textSecondary)
                Text(isArabic ? textAr : textEn)
                    .foregroundColor(available ? AppColors.textPrimary : AppColors.textSecondary)
            }
            .font(.body)
        }
    }
}

#Preview {
    NavigationView { UpgradeView().environmentObject(LanguageManager.shared) }
}
