import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var lang: LanguageManager
    @AppStorage("showOnboardingAfterLogin") private var showOnboardingAfterLogin: Bool = false

    // Collected data (UI-only for now)
    @AppStorage("ob_name") private var obName: String = ""
    @AppStorage("ob_gender") private var obGender: String = "male" // male|female
    @AppStorage("ob_age_group") private var obAgeGroup: String = "" // 13-17, 18-24, 25-34, 35-44, 45+
    @AppStorage("ob_apps") private var obApps: String = "" // comma-separated ids
    @AppStorage("ob_apps_other") private var obAppsOther: String = ""
    @AppStorage("ob_cats") private var obCats: String = "" // comma-separated ids
    @AppStorage("ob_cats_other") private var obCatsOther: String = ""
    @AppStorage("ob_goals") private var obGoals: String = "" // comma-separated ids
    @AppStorage("ob_goals_other") private var obGoalsOther: String = ""

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
            VStack(spacing: 16) {
                TabView(selection: $page) {
                    // Page 1: Name + Gender
                    VStack(spacing: 16) {
                        Text(lang.isArabicEffective ? "تعريف بسيط" : "Quick intro")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                            TextField(lang.isArabicEffective ? "اسمك" : "Your name", text: $obName)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .padding(12)
                                .background(AppColors.uiSurface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
                            Picker("", selection: Binding<String>(
                                get: { obGender },
                                set: { obGender = $0 }
                            )) {
                                Text(lang.isArabicEffective ? "ذكر" : "Male").tag("male")
                                Text(lang.isArabicEffective ? "أنثى" : "Female").tag("female")
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .background(AppColors.uiSurface)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                        .padding(.horizontal, 24)
                    }
                    .tag(0)

                    // Page 2: Age group
                    VStack(spacing: 16) {
                        Text(lang.isArabicEffective ? "العمر" : "Age")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        VStack(alignment: .center, spacing: 12) {
                            ageChip(title: lang.isArabicEffective ? "13–17" : "13–17", value: "13-17")
                            ageChip(title: lang.isArabicEffective ? "18–24" : "18–24", value: "18-24")
                            ageChip(title: lang.isArabicEffective ? "25–34" : "25–34", value: "25-34")
                            ageChip(title: lang.isArabicEffective ? "35–44" : "35–44", value: "35-44")
                            ageChip(title: lang.isArabicEffective ? "45+" : "45+", value: "45+")
                        }
                        .padding(16)
                        .background(AppColors.uiSurface)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                        .padding(.horizontal, 24)
                        Text(lang.isArabicEffective ? "اختيار تقريبي" : "Approximate selection")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .tag(1)

                    // Page 3: Addictive apps/categories
                    VStack(spacing: 16) {
                        Text(lang.isArabicEffective ? "مصادر الإدمان" : "Addictive sources")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        VStack(spacing: 16) {
                            // Apps section
                            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                                Text(lang.isArabicEffective ? "تطبيقات" : "Apps")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                ChipGrid(items: appOptions, selectedCSV: $obApps, isRTL: lang.isArabicEffective)
                                if obApps.split(separator: ",").contains("other") {
                                    TextField(lang.isArabicEffective ? "أخرى — اكتب هنا" : "Other — type here", text: $obAppsOther)
                                        .textInputAutocapitalization(.sentences)
                                        .disableAutocorrection(false)
                                        .padding(12)
                                        .background(AppColors.uiSurface)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
                                }
                            }
                            .padding(16)
                            .background(AppColors.uiSurface)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))

                            // Divider between sections (soft)
                            HStack { Spacer(); Rectangle().fill(AppColors.uiBorder.opacity(0.70)).frame(width: 300, height: 1); Spacer() }

                            // Categories section
                            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                                Text(lang.isArabicEffective ? "فئات" : "Categories")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                ChipGrid(items: catOptions, selectedCSV: $obCats, isRTL: lang.isArabicEffective)
                                if obCats.split(separator: ",").contains("other") {
                                    TextField(lang.isArabicEffective ? "أخرى — اكتب هنا" : "Other — type here", text: $obCatsOther)
                                        .textInputAutocapitalization(.sentences)
                                        .disableAutocorrection(false)
                                        .padding(12)
                                        .background(AppColors.uiSurface)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
                                }
                            }
                            .padding(16)
                            .background(AppColors.uiSurface)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                        }
                        .padding(.horizontal, 24)
                    }
                    .tag(2)

                    // Page 4: Goals
                    VStack(spacing: 16) {
                        Text(lang.isArabicEffective ? "هدفك من التطبيق؟" : "Your goal with the app?")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text(lang.isArabicEffective ? "يمكنك اختيار أكثر من هدف." : "You can pick more than one goal.")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                        VStack(spacing: 16) {
                            ForEach(Array(goalSections.enumerated()), id: \.offset) { idx, section in
                                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                                    Text(section.title)
                                        .font(.headline)
                                        .foregroundColor(AppColors.textPrimary)
                                    ChipGrid(items: section.items + [.init(id: "other", title: lang.isArabicEffective ? "أخرى" : "Other")], selectedCSV: $obGoals, isRTL: lang.isArabicEffective)
                                }
                                .padding(16)
                                .background(AppColors.uiSurface)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                                if idx != goalSections.count - 1 {
                                    HStack { Spacer(); Rectangle().fill(AppColors.uiBorder.opacity(0.70)).frame(width: 300, height: 1); Spacer() }
                                }
                            }
                            if obGoals.split(separator: ",").contains("other") {
                                TextField(lang.isArabicEffective ? "أخرى — اكتب هدفك" : "Other — your goal", text: $obGoalsOther)
                                    .textInputAutocapitalization(.sentences)
                                    .disableAutocorrection(false)
                                    .padding(12)
                                    .background(AppColors.uiSurface)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
                                    .padding(.horizontal, 24)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                HStack {
                    Button(action: { showOnboardingAfterLogin = false }) {
                        Text(lang.isArabicEffective ? "تخطي" : "Skip")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Button(action: { withAnimation { page = min(page + 1, 3) } }) {
                        Text(page < 3 ? (lang.isArabicEffective ? "التالي" : "Next") : (lang.isArabicEffective ? "إنهاء" : "Finish"))
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 120, height: 44)
                            .background(AppColors.accentDark)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        if page == 3 { showOnboardingAfterLogin = false }
                    })
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .background(AppColors.uiBackground)
        }
    }

    private func ageChip(title: String, value: String) -> some View {
        Button(action: { obAgeGroup = value }) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(obAgeGroup == value ? .white : AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(obAgeGroup == value ? AppColors.accentDark : AppColors.uiSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.uiBorder, lineWidth: obAgeGroup == value ? 0 : 0.5)
                )
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

private struct ChipGrid: View {
    let items: [OnboardingView.ChipItem]
    @Binding var selectedCSV: String
    let isRTL: Bool

    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 140), spacing: 8)] }

    var body: some View {
        let selected = Set(selectedCSV.split(separator: ",").map { String($0) })
        LazyVGrid(columns: columns, alignment: isRTL ? .trailing : .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.contains(item.id)
                Button(action: { toggle(item.id) }) {
                    Text(item.title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? AppColors.accentDark : AppColors.uiSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.uiBorder, lineWidth: isSelected ? 0 : 0.5)
                        )
                        .cornerRadius(12)
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