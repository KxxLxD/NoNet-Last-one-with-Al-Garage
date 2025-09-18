import SwiftUI

struct UpgradeView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isPremium") private var isPremium: Bool = false
    @AppStorage("trialStartTs") private var trialStartTs: Double = 0

    @State private var discountCode: String = ""
    @State private var isCodeApplied: Bool = false
    @State private var selectedPlan: String? = nil // "monthly" or "yearly"

    private var isArabic: Bool { lang.isArabicEffective }

    // Prices (SAR)
    private let monthlyBase = 30
    private let monthlyWithCode = 20 // with code nonet

    private let yearlyOriginal = 360
    private let yearlyAfterDeal = 300 // two months free (360 -> 300)
    private let yearlyWithCode = 200 // with code nonet

    private let trialDuration: TimeInterval = 7 * 24 * 3600

    private var isTrialActive: Bool {
        guard trialStartTs > 0 else { return false }
        let start = Date(timeIntervalSince1970: trialStartTs)
        return Date().timeIntervalSince(start) < trialDuration
    }

    private var trialDaysLeft: Int {
        guard trialStartTs > 0 else { return 0 }
        let start = Date(timeIntervalSince1970: trialStartTs)
        let remaining = max(0, trialDuration - Date().timeIntervalSince(start))
        return Int(ceil(remaining / 86400))
    }

    private var codeHint: String {
        isArabic ? "ادخل كود الخصم" : "Enter discount code"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Pricing
                Text(isArabic ? "الاشتراك المميز" : "Premium Pricing")
                    .font(.title2).bold()

                // Bilingual note about discount code
                Text(isArabic
                     ? "استخدم الكود nonet لتحصل على خصم الثلث.\nUse code nonet to get one‑third off."
                     : "Use code nonet to get one‑third off.\nاستخدم الكود nonet لتحصل على خصم الثلث.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                // Discount code input
                VStack(alignment: .leading, spacing: 8) {
                    Text(isArabic ? "كود الخصم" : "Discount Code").font(.subheadline)
                    HStack(spacing: 12) {
                        TextField(codeHint, text: $discountCode)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(12)
                            .background(AppColors.uiSurface)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
                        Button(action: applyCode) {
                            Text(isArabic ? "تطبيق" : "Apply")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(AppColors.accentDark)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    if isCodeApplied {
                        Text(isArabic ? "تم تطبيق خصم الثلث (كود nonet)" : "One-third discount applied (code: nonet)")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }

                // Monthly plan
                planCard(
                    title: isArabic ? "شهري" : "Monthly",
                    original: monthlyBase,
                    crossed: nil,
                    finalPrice: isCodeApplied ? monthlyWithCode : monthlyBase,
                    note: isArabic ? "باستخدام الكود nonet يصبح: 20 ريال" : "Use code nonet → 20 SAR",
                    showDiscountNote: isCodeApplied,
                    planKey: "monthly",
                    isSelected: selectedPlan == "monthly",
                    onSelect: { selectedPlan = "monthly" }
                )

                // Yearly plan with savings
                planCard(
                    title: isArabic ? "سنوي" : "Yearly",
                    original: yearlyOriginal,
                    crossed: yearlyAfterDeal,
                    finalPrice: isCodeApplied ? yearlyWithCode : yearlyAfterDeal,
                    note: isArabic ? "توفير شهرين (360 → 300). مع الكود nonet: 200 ريال" : "Two months free (360 → 300). With code nonet: 200 SAR",
                    showDiscountNote: isCodeApplied,
                    planKey: "yearly",
                    isSelected: selectedPlan == "yearly",
                    onSelect: { selectedPlan = "yearly" }
                )

                // Features Card (Hook + Benefits)
                VStack(alignment: .leading, spacing: 12) {
                    // Headline
                    Text(isArabic ? "حرّر تركيزك وغيّر عاداتك الرقمية" : "Unlock focus and change digital habits")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(isArabic ? "كل ما تحتاجه لتبقى على المسار الصحيح." : "Everything you need to stay on track.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    SoftDivider(width: 300, opacity: 0.7)

                    // Free tier summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isArabic ? "مجاني" : "Free")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        availabilityRow(icon: "list.bullet", textAr: "حتى ٣ قوائم حجب", textEn: "Up to 3 blocklists", available: true)
                        availabilityRow(icon: "lock.shield", textAr: "الوضع الصارم: ٣ مرات فقط", textEn: "Hard Mode: 3 uses only", available: true)
                        availabilityRow(icon: "calendar", textAr: "الجدولة الذكية", textEn: "Smart scheduling", available: false)
                        availabilityRow(icon: "clock", textAr: "جدولة الاستراحات", textEn: "Planned breaks", available: false)
                        availabilityRow(icon: "sparkles", textAr: "مساعد NoNet الذكي (AI)", textEn: "NoNet AI Chatbot", available: false)
                        availabilityRow(icon: "person.badge.shield.checkmark", textAr: "دعم أولوية", textEn: "Priority support", available: false)
                    }

                    SoftDivider(width: 300, opacity: 0.7)

                    // Premium features (exactly 6)
                    VStack(alignment: .leading, spacing: 10) {
                        featureRow(icon: "infinity", textAr: "قوائم بلا حدود", textEn: "Unlimited blocklists")
                        featureRow(icon: "lock.shield", textAr: "الوضع الصارم", textEn: "Hard Mode")
                        featureRow(icon: "calendar", textAr: "الجدولة الذكية", textEn: "Smart scheduling")
                        featureRow(icon: "clock", textAr: "جدولة الاستراحات", textEn: "Planned breaks")
                        featureRow(icon: "sparkles", textAr: "مساعد NoNet الذكي (AI)", textEn: "NoNet AI Chatbot")
                        featureRow(icon: "person.badge.shield.checkmark", textAr: "دعم أولوية", textEn: "Priority support")
                        // Short description
                        Text(isArabic ? "مزايا عملية تمنحك سيطرة هادئة ودائمة." : "Practical features that keep you calmly in control.")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(20)
                .background(AppColors.uiSurface)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))

                // Golden Guarantee — prominent card
                VStack(alignment: .leading, spacing: 8) {
                    let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkerboard")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(gold)
                        Text(isArabic ? "الضمان الذهبي" : "Golden Guarantee")
                            .font(.headline)
                            .foregroundColor(gold)
                    }
                    Text(isArabic ? "استرداد كامل للمبلغ بدون أسئلة." : "Full refund, no questions asked.")
                        .foregroundColor(AppColors.textPrimary)
                    Text(isArabic ? "الشهري: خلال 14 يوم — السنوي: خلال شهر واحد." : "Monthly: within 14 days — Yearly: within 1 month.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
                .background(Color(red: 212/255, green: 175/255, blue: 55/255).opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 212/255, green: 175/255, blue: 55/255), lineWidth: 1))
                .cornerRadius(16)

                // CTA inline moved to bottom safe-area inset
                EmptyView()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .background(AppColors.uiBackground)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: activatePremium) {
                    Text(
                        selectedPlan == "monthly"
                        ? (isArabic ? "ابدأ الشهرية الآن" : "Start Monthly")
                        : selectedPlan == "yearly"
                        ? (isArabic ? "ابدأ السنوية الآن" : "Start Yearly")
                        : (isArabic ? "اختر خطة للمتابعة" : "Select a plan to continue")
                    )
                    .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.accentDark)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedPlan == nil)
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
    }

    private func startTrial() {
        guard trialStartTs == 0 else { return }
        trialStartTs = Date().timeIntervalSince1970
        isPremium = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func applyCode() {
        let code = discountCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        isCodeApplied = (code == "nonet")
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func activatePremium() {
        isPremium = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func planCard(title: String, original: Int, crossed: Int?, finalPrice: Int, note: String, showDiscountNote: Bool, planKey: String, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(original) \(isArabic ? "ريال" : "SAR")")
                    .foregroundColor(.secondary)
                    .strikethrough(crossed != nil, color: .secondary)
                if let crossed = crossed {
                    Text("\(crossed) \(isArabic ? "ريال" : "SAR")")
                        .foregroundColor(.secondary)
                        .strikethrough(false)
                }
                Spacer()
                Text("\(finalPrice) \(isArabic ? "ريال" : "SAR")")
                    .font(.title3).bold()
                    .foregroundColor(AppColors.accentDark)
            }
            if showDiscountNote {
                Text(note).font(.footnote).foregroundColor(.secondary)
            }
            HStack {
                Spacer()
                Button(action: onSelect) {
                    Text(isSelected ? (isArabic ? "محدد" : "Selected") : (isArabic ? "اختر" : "Select"))
                        .font(.subheadline.weight(.semibold))
                        .frame(height: 36)
                        .padding(.horizontal, 12)
                        .background(isSelected ? AppColors.infoBg : Color.clear)
                        .foregroundColor(AppColors.accentDark)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.accentDark, lineWidth: 1.5))
                        .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? AppColors.accentDark : AppColors.uiBorder, lineWidth: isSelected ? 1 : 0.5)
        )
    }

    // MARK: - Feature Row helpers
    @ViewBuilder
    private func featureRow(icon: String, textAr: String, textEn: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accentDark)
            VStack(alignment: .leading, spacing: 2) {
                Text(isArabic ? textAr : textEn)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }

    @ViewBuilder
    private func availabilityRow(icon: String, textAr: String, textEn: String, available: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(available ? AppColors.accentDark : AppColors.textSecondary)
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(available ? AppColors.accentDark : AppColors.textSecondary)
                Text(isArabic ? textAr : textEn)
                    .foregroundColor(available ? AppColors.textPrimary : AppColors.textSecondary)
            }
            .font(.body)
        }
    }
}

private struct SoftDivider: View {
    let width: CGFloat
    let opacity: Double
    var body: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.uiBorder.opacity(opacity))
                .frame(width: width, height: 1)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView { UpgradeView().environmentObject(LanguageManager.shared) }
} 