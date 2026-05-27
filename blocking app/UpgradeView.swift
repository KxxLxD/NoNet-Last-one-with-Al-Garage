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
    #if DEBUG
    // Admin/QA backdoor — stripped from Release builds so the App Store
    // binary doesn't ship a paywall bypass.
    @State private var showAdminSheet: Bool = false
    #endif

    private var isArabic: Bool { lang.isArabicEffective }

    private var monthlyProduct: Product? { store.products.first { $0.id == ProductIDs.monthly } }
    private var yearlyProduct: Product? { store.products.first { $0.id == ProductIDs.yearly } }

    private var isTrialActive: Bool {
        guard trialStartTs > 0 else { return false }
        let start = Date(timeIntervalSince1970: trialStartTs)
        return Date().timeIntervalSince(start) < BlockingConstants.trialDurationSeconds
    }

    private var trialDaysRemaining: Int {
        guard isTrialActive else { return 0 }
        let start = Date(timeIntervalSince1970: trialStartTs)
        let remaining = BlockingConstants.trialDurationSeconds - Date().timeIntervalSince(start)
        return max(0, Int(ceil(remaining / BlockingConstants.secondsPerDayInterval)))
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
        #if DEBUG
        .sheet(isPresented: $showAdminSheet) {
            AdminToolsSheet().environmentObject(lang)
        }
        #endif
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
                subscriptionTerms
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
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
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
                badge: flexBadge,
                isSelected: selectedPlan == "monthly"
            )
        }
    }

    /// Outline-style "FLEX" tag on the Monthly card so it doesn't read as a
    /// silent second-place option next to the prominent SAVE % on Yearly.
    /// Outline (clear background + accent stroke) signals "valid alternative,
    /// not the recommended pick" without competing with the filled BEST VALUE.
    private var flexBadge: PlanBadge {
        PlanBadge(text: isArabic ? "مرن" : "FLEX", color: AppColors.textSecondary)
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
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = planKey
            }
        }) {
            HStack(spacing: NNSpacing.sm) {
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
                                .padding(.horizontal, NNSpacing.xs - 2)
                                .padding(.vertical, NNSpacing.xxs - 2)
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
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.card)
                    .stroke(isSelected ? AppColors.accent : AppColors.uiBorder,
                            lineWidth: isSelected ? 1.5 : NNBorder.hairline)
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
                // Recovery Partner sits next to Hard Mode because it's a
                // Hard-Mode-only feature; users who care about one almost
                // always care about the other. The "NEW" badge highlights
                // the recently promoted Premium differentiator so it doesn't
                // get skimmed past.
                featureRow(icon: "person.2.fill",
                           textAr: "شريك التعافي (Hard Mode)",
                           textEn: "Recovery Partner (Hard Mode)",
                           badgeAr: "جديد",
                           badgeEn: "NEW")
                featureRow(icon: "calendar",    textAr: "الجدولة الذكية",              textEn: "Smart scheduling")
                featureRow(icon: "cup.and.saucer", textAr: "جدولة الاستراحات",        textEn: "Planned breaks")
                featureRow(icon: "sparkles",    textAr: "مساعد NoNet الذكي",         textEn: "NoNet AI assistant")
                featureRow(icon: "person.badge.shield.checkmark", textAr: "دعم بأولوية", textEn: "Priority support")
            }
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.card)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    @ViewBuilder
    private func featureRow(
        icon: String,
        textAr: String,
        textEn: String,
        badgeAr: String? = nil,
        badgeEn: String? = nil
    ) -> some View {
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
            // Optional trailing badge (e.g. "NEW") to highlight a freshly
            // added feature. Uses the same accent-filled capsule pattern as
            // the plan-selector SAVE % badge so the visual language is
            // consistent across the page.
            if let badgeText = isArabic ? badgeAr : badgeEn {
                Text(badgeText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, NNSpacing.xs - 2)
                    .padding(.vertical, NNSpacing.xxs - 2)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var goldenGuarantee: some View {
        // Unified palette: green throughout (icon, title, background tint,
        // border). The previous mix of gold background + green icon created
        // a "premium tier vs. safe" cognitive clash — the message is "your
        // money is safe", which green communicates universally. Brand keeps
        // the word "Golden" in copy without depending on gold pigment.
        //
        // Layout: the refund windows are surfaced as two scannable rows
        // (replacing the previous prose paragraph) because they're the
        // numbers users actually care about. The "via Apple, we help if
        // denied" line moves to a smaller caption underneath — it's
        // explanation, not headline.
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.successGreen)
                Text(isArabic ? "الضمان الذهبي" : "Golden Guarantee")
                    .font(.headline)
                    .foregroundColor(AppColors.successGreen)
                Spacer(minLength: 0)
            }
            Text(isArabic ? "استرداد كامل بدون أسئلة." : "Full refund, no questions asked.")
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xxs) {
                refundRow(textAr: "شهر للاشتراك الشهري",
                          textEn: "1 month for monthly")
                refundRow(textAr: "شهرين للاشتراك السنوي",
                          textEn: "2 months for yearly")
            }
            .padding(.top, NNSpacing.xxs)

            Text(isArabic
                ? "يُطلب الاسترداد من تطبيق App Store مباشرة. لو رفضته Apple، تواصل معنا ونساعدك."
                : "Refunds requested via the App Store. If Apple denies it, contact us and we'll help.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(isArabic ? .trailing : .leading)
        }
        .padding(NNSpacing.md)
        .background(AppColors.successBg)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.card)
                .stroke(AppColors.successGreen.opacity(0.5), lineWidth: NNBorder.input)
        )
    }

    /// Single bullet row inside the Golden Guarantee card. Pulled out of the
    /// `goldenGuarantee` body so the two refund-window lines can be defined
    /// without duplicating the icon/typography/colour decisions.
    @ViewBuilder
    private func refundRow(textAr: String, textEn: String) -> some View {
        HStack(spacing: NNSpacing.xs) {
            Image(systemName: "calendar.badge.checkmark")
                .foregroundColor(AppColors.successGreen)
                .font(.footnote)
            Text(isArabic ? textAr : textEn)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
            Spacer(minLength: 0)
        }
    }

    /// Apple App Review §3.1.2(a) disclosures — auto-renewal, cancellation
    /// path, payment channel. The Terms of Service has the long-form version
    /// (LegalContent.swift §5 of Terms); this card surfaces the *required*
    /// bullets on the paywall itself so the reviewer doesn't have to dig.
    /// Neutral palette (no card border) so it reads as informational rather
    /// than a "feature" — the previous Golden Guarantee card already owns
    /// the trust accent above it.
    @ViewBuilder
    private var subscriptionTerms: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xs) {
            termsLine(textAr: "يتجدد الاشتراك تلقائياً ما لم تُلغِه قبل 24 ساعة من نهاية الفترة.",
                      textEn: "Subscription auto-renews unless cancelled at least 24 hours before the end of the current period.")
            termsLine(textAr: "تقدر تلغي في أي وقت من: الإعدادات → Apple ID → الاشتراكات.",
                      textEn: "Cancel anytime from: Settings → Apple ID → Subscriptions.")
            termsLine(textAr: "المدفوعات تُعالج بالكامل عبر App Store.",
                      textEn: "All payments are processed by the App Store.")
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.card)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    @ViewBuilder
    private func termsLine(textAr: String, textEn: String) -> some View {
        HStack(alignment: .top, spacing: NNSpacing.xs) {
            Image(systemName: "checkmark")
                .foregroundColor(AppColors.textSecondary)
                .font(.caption2)
                .padding(.top, 3)
            Text(isArabic ? textAr : textEn)
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(isArabic ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
        }
    }

    @ViewBuilder
    private var footerActions: some View {
        // Redeem (primary footer action, accent color) and Restore (secondary
        // help action, smaller caption) split visually with a divider so they
        // read as two distinct concepts rather than a twin pair.
        VStack(spacing: NNSpacing.xs) {
            Button(action: { Task { await store.presentRedeemSheet() } }) {
                HStack(spacing: NNSpacing.xs) {
                    Image(systemName: "ticket")
                    Text(isArabic ? "لديك كود؟ استرده" : "Have a code? Redeem")
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.accent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: NNHitTarget.minimum)
            }
            .buttonStyle(.plain)

            SoftDivider(maxWidth: 200, opacity: 0.4)

            Button(action: { Task { await store.restorePurchases() } }) {
                Text(isArabic ? "اشترك سابقاً؟ استعادة المشتريات" : "Already subscribed? Restore purchases")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: NNHitTarget.minimum)
            }
            .buttonStyle(.plain)

            // Apple §3.1.2(a) compliance: dedicated, distinct links to Terms
            // and Privacy must be visible BEFORE purchase. Each deep-links to
            // its own segment in PoliciesView (initialTab: 0 = Terms, 1 =
            // Privacy) so a reviewer tapping either lands on the right doc.
            legalLinksRow

            // Entity credit — GDPR Art. 13 + PDPL transparency: the user
            // should see who they're paying on the payment screen. Sourced
            // from LegalContent so it auto-syncs with the official entity
            // name in the policy documents.
            entityCredit

            #if DEBUG
            // Admin/QA trigger — Debug-only so the App Store binary doesn't
            // ship a paywall bypass. Compiled out entirely in Release.
            adminTrigger
            #endif
        }
        .padding(.top, NNSpacing.sm)
    }

    @ViewBuilder
    private var legalLinksRow: some View {
        HStack(spacing: NNSpacing.xs) {
            Spacer(minLength: 0)
            NavigationLink(destination: PoliciesView(initialTab: 0).environmentObject(lang)) {
                Text(isArabic ? "الشروط والأحكام" : "Terms of Service")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.accent)
            }
            Text("·")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary.opacity(0.6))
            NavigationLink(destination: PoliciesView(initialTab: 1).environmentObject(lang)) {
                Text(isArabic ? "سياسة الخصوصية" : "Privacy Policy")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.accent)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: NNHitTarget.minimum)
    }

    @ViewBuilder
    private var entityCredit: some View {
        Text("© \(currentYearString) \(LegalContent.entityName)")
            .font(.caption2)
            .foregroundColor(AppColors.textSecondary.opacity(0.7))
            .frame(maxWidth: .infinity)
    }

    /// Stale-proof year for the copyright line. Computed at render time so
    /// the footer never goes out of date.
    private var currentYearString: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    #if DEBUG
    @ViewBuilder
    private var adminTrigger: some View {
        // Visible enough for the developer to find at a glance ("براحتي")
        // but still styled as low-contrast footer text so it doesn't compete
        // with the real footer actions above. Debug builds only.
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAdminSheet = true
        }) {
            HStack(spacing: NNSpacing.xxs) {
                Image(systemName: "key.fill")
                    .font(.caption2)
                Text(isArabic ? "دخول الأدمن" : "Admin")
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(AppColors.textSecondary.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: NNHitTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isArabic ? "أدوات الأدمن" : "Admin tools")
    }
    #endif

    @ViewBuilder
    private var stickyCTA: some View {
        VStack(spacing: NNSpacing.xs) {
            // Helper caption above the CTA. Priority order:
            //   1. Products still loading → say so explicitly (was silent before).
            //   2. No plan selected → prompt the user to pick one.
            // Both cases otherwise leave the user staring at a disabled button.
            if selectedProduct == nil && selectedPlan != nil {
                HStack(spacing: NNSpacing.xxs) {
                    ProgressView().scaleEffect(0.7)
                    Text(isArabic ? "جاري تحميل الباقات من App Store…" : "Loading plans from App Store…")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            } else if selectedPlan == nil {
                Text(isArabic ? "اختر خطة للمتابعة" : "Select a plan to continue")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Button(action: { Task { await activatePremium() } }) {
                Text(ctaLabel)
                    .font(.nnButton)
                    .frame(maxWidth: .infinity)
                    .frame(height: NNHitTarget.minimum + 6)
                    .background(canPurchase ? AppColors.accent : AppColors.textDisabled)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control + 2))
            }
            .disabled(!canPurchase)
            .buttonStyle(.plain)

            // Cancel-anytime reassurance directly under the purchase button.
            // Conversion lever + Apple §3.1.2(a) best-practice signal: the
            // user shouldn't have to scroll to confirm they can back out.
            Text(isArabic ? "يمكنك الإلغاء في أي وقت من App Store" : "Cancel anytime in App Store")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
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
                        HStack(spacing: NNSpacing.xs) {
                            Image(systemName: "creditcard.fill")
                            Text(isArabic ? "إدارة الاشتراك في App Store" : "Manage subscription in App Store")
                        }
                        .font(.nnButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: NNHitTarget.minimum + 6)
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control + 2))
                    }
                    .buttonStyle(.plain)

                    Button(action: { Task { await store.restorePurchases() } }) {
                        Text(isArabic ? "استعادة المشتريات" : "Restore Purchases")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: NNHitTarget.minimum)
                    }
                    .buttonStyle(.plain)

                    #if DEBUG
                    adminTrigger
                    #endif
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
