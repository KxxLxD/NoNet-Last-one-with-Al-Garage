import SwiftUI
import CoreData

struct OnboardingView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.managedObjectContext) private var context
    @AppStorage(AppStorageKeys.showOnboardingAfterLogin) private var showOnboardingAfterLogin: Bool = false

    // Collected data (UI-only for now)
    @AppStorage(AppStorageKeys.obName) private var obName: String = ""
    @AppStorage(AppStorageKeys.obGender) private var obGender: String = "male" // male|female
    @AppStorage(AppStorageKeys.obAgeGroup) private var obAgeGroup: String = "" // 13-17, 18-24, 25-34, 35-44, 45+
    @AppStorage(AppStorageKeys.obApps) private var obApps: String = "" // comma-separated ids
    @AppStorage(AppStorageKeys.obAppsOther) private var obAppsOther: String = ""
    @AppStorage(AppStorageKeys.obCats) private var obCats: String = "" // comma-separated ids
    @AppStorage(AppStorageKeys.obCatsOther) private var obCatsOther: String = ""
    @AppStorage(AppStorageKeys.obGoals) private var obGoals: String = "" // comma-separated ids
    @AppStorage(AppStorageKeys.obGoalsOther) private var obGoalsOther: String = ""

    @State private var page: Int = 0

    struct ChipItem: Hashable { let id: String; let title: String }

    private var appOptions: [ChipItem] {
        if lang.isArabicEffective {
            return [
                .init(id: "tiktok", title: "TikTok"),
                .init(id: "youtube", title: "YouTube"),
                .init(id: "instagram", title: "Instagram"),
                .init(id: "snapchat", title: "Snapchat"),
                .init(id: "x", title: "X (تويتر)"),
                .init(id: "games", title: "الألعاب"),
                .init(id: "other", title: "أخرى")
            ]
        }
        return [
            .init(id: "tiktok", title: "TikTok"),
            .init(id: "youtube", title: "YouTube"),
            .init(id: "instagram", title: "Instagram"),
            .init(id: "snapchat", title: "Snapchat"),
            .init(id: "x", title: "X (Twitter)"),
            .init(id: "games", title: "Games"),
            .init(id: "other", title: "Other")
        ]
    }

    private var catOptions: [ChipItem] {
        if lang.isArabicEffective {
            return [
                .init(id: "social", title: "السوشيال"),
                .init(id: "short_videos", title: "المقاطع القصيرة"),
                .init(id: "gaming", title: "الألعاب"),
                .init(id: "adult", title: "الإباحية"),
                .init(id: "gambling", title: "القمار"),
                .init(id: "shopping", title: "التسوق"),
                .init(id: "news", title: "الأخبار"),
                .init(id: "other", title: "أخرى")
            ]
        }
        return [
            .init(id: "social", title: "Social"),
            .init(id: "short_videos", title: "Short Videos"),
            .init(id: "gaming", title: "Gaming"),
            .init(id: "adult", title: "Adult"),
            .init(id: "gambling", title: "Gambling"),
            .init(id: "shopping", title: "Shopping"),
            .init(id: "news", title: "News"),
            .init(id: "other", title: "Other")
        ]
    }

    private var goalSections: [(title: String, items: [ChipItem])] {
        if lang.isArabicEffective {
            return [
                ("الصحة والنفس", [
                    .init(id: "lower_stress", title: "تقليل التوتر والقلق"),
                    .init(id: "better_sleep", title: "تحسين النوم"),
                    .init(id: "better_mood", title: "تخفيف الاكتئاب")
                ]),
                ("التركيز والأداء", [
                    .init(id: "improve_focus", title: "تحسين التركيز"),
                    .init(id: "increase_productivity", title: "زيادة الإنتاجية"),
                    .init(id: "academic_performance", title: "رفع التحصيل الدراسي"),
                    .init(id: "work_performance", title: "تحسين الأداء في العمل")
                ]),
                ("العادات الرقمية", [
                    .init(id: "reduce_shorts", title: "تقليل الشورتس"),
                    .init(id: "quit_adult", title: "ترك الإباحية"),
                    .init(id: "quit_gambling", title: "ترك القمار"),
                    .init(id: "reduce_shopping", title: "تقليل الشراء"),
                    .init(id: "reduce_dating", title: "تقليل تطبيقات المواعدة")
                ]),
                ("النمو والتطوير", [
                    .init(id: "self_growth", title: "تحسين النمو"),
                    .init(id: "less_screen", title: "تقليل وقت الشاشة")
                ])
            ]
        }
        return [
            ("Health & Mind", [
                .init(id: "lower_stress", title: "Reduce stress & anxiety"),
                .init(id: "better_sleep", title: "Improve sleep"),
                .init(id: "better_mood", title: "Lift mood / depression")
            ]),
            ("Focus & Performance", [
                .init(id: "improve_focus", title: "Improve focus"),
                .init(id: "increase_productivity", title: "Increase productivity"),
                .init(id: "academic_performance", title: "Better academic results"),
                .init(id: "work_performance", title: "Better at work")
            ]),
            ("Digital Habits", [
                .init(id: "reduce_shorts", title: "Reduce shorts/reels"),
                .init(id: "quit_adult", title: "Quit adult content"),
                .init(id: "quit_gambling", title: "Quit gambling"),
                .init(id: "reduce_shopping", title: "Reduce shopping"),
                .init(id: "reduce_dating", title: "Reduce dating apps")
            ]),
            ("Growth", [
                .init(id: "self_growth", title: "Personal growth"),
                .init(id: "less_screen", title: "Less screen time")
            ])
        ]
    }

    var body: some View {
        NavigationView {
            VStack(spacing: NNSpacing.md) {
                TabView(selection: $page) {
                    // Page 1: Name + Gender
                    VStack(spacing: NNSpacing.md) {
                        Text(lang.isArabicEffective ? "تعريف بسيط" : "Quick intro")
                            .font(.nnSectionTitle)
                            .foregroundColor(AppColors.textPrimary)
                        whyHint(lang.isArabicEffective
                                ? "نستخدم اسمك في الترحيب فقط. بياناتك تبقى على جهازك — iCloud اختياري لميزة شريك التعافي فقط."
                                : "We use your name for greetings only. Your data stays on your device — iCloud is optional for the Recovery Partner feature only.")
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                            TextField(lang.isArabicEffective ? "اسمك" : "Your name", text: $obName)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .padding(NNSpacing.sm)
                                .background(AppColors.uiSurface)
                                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                                .overlay(
                                    RoundedRectangle(cornerRadius: NNRadius.control)
                                        .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
                                )
                            Picker("", selection: Binding<String>(
                                get: { obGender },
                                set: { obGender = $0 }
                            )) {
                                Text(lang.isArabicEffective ? "ذكر" : "Male").tag("male")
                                Text(lang.isArabicEffective ? "أنثى" : "Female").tag("female")
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(NNSpacing.md)
                        .background(AppColors.uiSurface)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
                        .overlay(
                            RoundedRectangle(cornerRadius: NNRadius.container)
                                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                        )
                        .padding(.horizontal, NNSpacing.xl)
                    }
                    .tag(0)

                    // Page 2: Age group
                    VStack(spacing: NNSpacing.md) {
                        Text(lang.isArabicEffective ? "العمر" : "Age")
                            .font(.nnSectionTitle)
                            .foregroundColor(AppColors.textPrimary)
                        whyHint(lang.isArabicEffective
                                ? "يساعدنا على اقتراح خطط مناسبة (مثل وقت النوم للمراهقين أو ساعات العمل للبالغين)."
                                : "Helps us suggest plans that fit your stage (e.g. sleep schedules for teens, work hours for adults).")
                        VStack(alignment: .center, spacing: NNSpacing.sm) {
                            ageChip(title: lang.isArabicEffective ? "13–17" : "13–17", value: "13-17")
                            ageChip(title: lang.isArabicEffective ? "18–24" : "18–24", value: "18-24")
                            ageChip(title: lang.isArabicEffective ? "25–34" : "25–34", value: "25-34")
                            ageChip(title: lang.isArabicEffective ? "35–44" : "35–44", value: "35-44")
                            ageChip(title: lang.isArabicEffective ? "45+" : "45+", value: "45+")
                        }
                        .padding(NNSpacing.md)
                        .background(AppColors.uiSurface)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
                        .overlay(
                            RoundedRectangle(cornerRadius: NNRadius.container)
                                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                        )
                        .padding(.horizontal, NNSpacing.xl)
                        Text(lang.isArabicEffective ? "اختيار تقريبي" : "Approximate selection")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .tag(1)

                    // Page 3: Addictive apps/categories
                    VStack(spacing: NNSpacing.md) {
                        Text(lang.isArabicEffective ? "مصادر الإدمان" : "Addictive sources")
                            .font(.nnSectionTitle)
                            .foregroundColor(AppColors.textPrimary)
                        whyHint(lang.isArabicEffective
                                ? "اختياراتك تظهر كاقتراحات جاهزة عند إنشاء أول قائمة حجب."
                                : "Your picks appear as ready-made suggestions when you create your first blocklist.")
                        VStack(spacing: NNSpacing.md) {
                            // Apps section
                            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                                Text(lang.isArabicEffective ? "تطبيقات" : "Apps")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                ChipGrid(items: appOptions, selectedCSV: $obApps, isRTL: lang.isArabicEffective)
                                if obApps.split(separator: ",").contains("other") {
                                    otherTextField(placeholder: lang.isArabicEffective ? "أخرى — اكتب هنا" : "Other — type here", text: $obAppsOther)
                                }
                            }
                            .padding(NNSpacing.md)
                            .background(AppColors.uiSurface)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
                            .overlay(
                                RoundedRectangle(cornerRadius: NNRadius.container)
                                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                            )

                            SoftDivider(maxWidth: 320, opacity: 0.7)

                            // Categories section
                            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                                Text(lang.isArabicEffective ? "فئات" : "Categories")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                ChipGrid(items: catOptions, selectedCSV: $obCats, isRTL: lang.isArabicEffective)
                                if obCats.split(separator: ",").contains("other") {
                                    otherTextField(placeholder: lang.isArabicEffective ? "أخرى — اكتب هنا" : "Other — type here", text: $obCatsOther)
                                }
                            }
                            .padding(NNSpacing.md)
                            .background(AppColors.uiSurface)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
                            .overlay(
                                RoundedRectangle(cornerRadius: NNRadius.container)
                                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                            )
                        }
                        .padding(.horizontal, NNSpacing.xl)
                    }
                    .tag(2)

                    // Page 4: Goals
                    VStack(spacing: NNSpacing.md) {
                        Text(lang.isArabicEffective ? "هدفك من التطبيق؟" : "Your goal with the app?")
                            .font(.nnSectionTitle)
                            .foregroundColor(AppColors.textPrimary)
                        Text(lang.isArabicEffective ? "يمكنك اختيار أكثر من هدف." : "You can pick more than one goal.")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                        VStack(spacing: NNSpacing.md) {
                            ForEach(Array(goalSections.enumerated()), id: \.offset) { idx, section in
                                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                                    Text(section.title)
                                        .font(.headline)
                                        .foregroundColor(AppColors.textPrimary)
                                    ChipGrid(items: section.items + [.init(id: "other", title: lang.isArabicEffective ? "أخرى" : "Other")], selectedCSV: $obGoals, isRTL: lang.isArabicEffective)
                                }
                                .padding(NNSpacing.md)
                                .background(AppColors.uiSurface)
                                .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
                                .overlay(
                                    RoundedRectangle(cornerRadius: NNRadius.container)
                                        .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                                )
                                if idx != goalSections.count - 1 {
                                    SoftDivider(maxWidth: 320, opacity: 0.7)
                                }
                            }
                            if obGoals.split(separator: ",").contains("other") {
                                otherTextField(placeholder: lang.isArabicEffective ? "أخرى — اكتب هدفك" : "Other — your goal", text: $obGoalsOther)
                                    .padding(.horizontal, NNSpacing.xl)
                            }
                        }
                        .padding(.horizontal, NNSpacing.xl)
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // Explicit step counter — dot-indicators alone don't tell users
                // the total step count until they page through the whole flow.
                Text(lang.isArabicEffective
                     ? "خطوة \(page + 1) من 4"
                     : "Step \(page + 1) of 4")
                    .font(.nnCaption)
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()

                HStack {
                    // Skip is a quiet text link — secondary action. Capitalized
                    // text size + no background keeps "Next" the obvious primary
                    // even at a glance.
                    Button(action: { showOnboardingAfterLogin = false }) {
                        Text(lang.isArabicEffective ? "تخطي" : "Skip")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, NNSpacing.sm)
                    }
                    .frame(minHeight: NNHitTarget.minimum)
                    .accessibilityLabel(lang.isArabicEffective ? "تخطي التعريف والذهاب للرئيسية" : "Skip intro and go to home")
                    Spacer()
                    Button(action: { withAnimation { page = min(page + 1, 3) } }) {
                        Text(page < 3 ? (lang.isArabicEffective ? "التالي" : "Next") : (lang.isArabicEffective ? "إنهاء" : "Finish"))
                            .font(.nnButton)
                            .frame(width: 120, height: NNHitTarget.minimum)
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        if page == 3 {
                            // Seed a goal-shaped first list (inactive — user must
                            // tap to activate). Skipping onboarding bypasses this:
                            // skip means the user explicitly opted out of sharing
                            // their goal data, so we don't pretend to use it.
                            SmartListSeeder.seedIfNeeded(in: context)
                            showOnboardingAfterLogin = false
                        }
                    })
                }
                .padding(.horizontal, NNSpacing.xl)
                .padding(.bottom, NNSpacing.xs)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .background(AppColors.uiBackground)
        }
    }

    /// Small "why we're asking" line shown under each onboarding step title.
    /// Builds trust before personal information — users are far more willing
    /// to share when they understand the purpose. info.circle icon signals
    /// "this is context, not required reading."
    @ViewBuilder
    private func whyHint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: NNSpacing.xs) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(AppColors.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
        }
        .padding(.horizontal, NNSpacing.xl)
    }

    /// "Other — write here" text field — shared so the four pages don't each
    /// reimplement the same TextField + border + radius.
    @ViewBuilder
    private func otherTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(false)
            .padding(NNSpacing.sm)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.control)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
            )
    }

    private func ageChip(title: String, value: String) -> some View {
        Button(action: { obAgeGroup = value }) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(obAgeGroup == value ? .white : AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: NNHitTarget.minimum)
                .background(obAgeGroup == value ? AppColors.accent : AppColors.uiSurface)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: NNRadius.control)
                        .stroke(AppColors.uiBorder, lineWidth: obAgeGroup == value ? 0 : NNBorder.hairline)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ChipGrid: View {
    let items: [OnboardingView.ChipItem]
    @Binding var selectedCSV: String
    let isRTL: Bool

    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 140), spacing: NNSpacing.xs)] }

    var body: some View {
        let selected = Set(selectedCSV.split(separator: ",").map { String($0) })
        LazyVGrid(columns: columns, alignment: isRTL ? .trailing : .leading, spacing: NNSpacing.xs) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.contains(item.id)
                Button(action: { toggle(item.id) }) {
                    Text(item.title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                        .padding(.horizontal, NNSpacing.sm)
                        .padding(.vertical, NNSpacing.xs)
                        .background(isSelected ? AppColors.accent : AppColors.uiSurface)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: NNRadius.control)
                                .stroke(AppColors.uiBorder, lineWidth: isSelected ? 0 : NNBorder.hairline)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ id: String) {
        var parts = selectedCSV.split(separator: ",").map { String($0) }
        if let idx = parts.firstIndex(of: id) {
            parts.remove(at: idx)
        } else {
            parts.append(id)
        }
        selectedCSV = parts.joined(separator: ",")
    }
}

#Preview {
    OnboardingView().environmentObject(LanguageManager.shared)
} 