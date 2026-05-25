import SwiftUI

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    enum LanguageOption: String {
        case system
        case arabic
        case english
    }

    @Published var selected: LanguageOption

    var isArabicEffective: Bool {
        switch selected {
        case .arabic:
            return true
        case .english:
            return false
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("ar")
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "AppLanguage"), let opt = LanguageOption(rawValue: raw) {
            selected = opt
        } else {
            selected = .system
        }
    }

    func updateLanguage(_ newLanguage: LanguageOption) {
        selected = newLanguage
        UserDefaults.standard.set(selected.rawValue, forKey: "AppLanguage")
    }
}

/// NoNet Design System — Color Tokens
///
/// Source of truth: `.cursor/rules/UI-Mode.mdc`.
/// Single canonical accent (`accent`) at #2563EB (contrast 4.83:1 on white — AA pass).
/// All button/CTA usages MUST use `accent`. Legacy `accentDark`/`primaryBlue` aliases
/// remain to avoid bulk-rename churn; they all resolve to the same #2563EB.
struct AppColors {
    // MARK: - Canonical Accent (single source)
    /// Primary accent — use for ALL buttons, CTAs, links, selected states.
    /// AA contrast 4.83:1 on white surface ✅
    static let accent = Color(red: 37/255, green: 99/255, blue: 235/255) // #2563EB

    // MARK: - Semantic State Tokens
    static let alertRed = Color(red: 239/255, green: 68/255, blue: 68/255)     // #EF4444
    static let successGreen = Color(red: 16/255, green: 185/255, blue: 129/255) // #10B981
    static let warningFg = Color(red: 245/255, green: 158/255, blue: 11/255)    // #F59E0B
    static let warningBg = Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.1) // #F59E0B1A
    static let dangerBg  = Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.1)  // #EF44441A
    static let infoFg = accent
    static let infoBg = accent.opacity(0.1) // #2563EB1A
    static let successBg = successGreen.opacity(0.1) // #10B9811A

    // MARK: - Surface / Background
    static let uiBackground = Color(red: 243/255, green: 244/255, blue: 246/255) // #F3F4F6
    static let uiSurface = Color.white // #FFFFFF
    static let uiBorder = Color(red: 229/255, green: 231/255, blue: 235/255) // #E5E7EB

    // MARK: - Text
    static let textPrimary = Color(red: 55/255, green: 65/255, blue: 81/255)   // #374151 (AAA on bg)
    static let textSecondary = Color(red: 107/255, green: 114/255, blue: 128/255) // #6B7280 (AA on surface)
    static let textDisabled  = Color(red: 156/255, green: 163/255, blue: 175/255) // #9CA3AF

    // MARK: - Specialty (limited use)
    /// Calm trophy gold — achievements/golden-guarantee only. Do not use as accent.
    static let trophyGold = Color(red: 212/255, green: 175/255, blue: 55/255) // #D4AF37
    /// Soft accent for decorative gradients only. Never use for text/buttons.
    static let accentLight = Color(red: 140/255, green: 188/255, blue: 252/255) // #8CBCFC

    // MARK: - Legacy aliases (DO NOT use in new code)
    // Kept to avoid bulk rename. All resolve to canonical `accent`.
    @available(*, deprecated, renamed: "accent", message: "Use AppColors.accent")
    static let primaryBlue = accent
    @available(*, deprecated, renamed: "accent", message: "Use AppColors.accent. The old #4DA2FC failed AA contrast; this now resolves to #2563EB.")
    static let accentDark = accent
    @available(*, deprecated, renamed: "accent", message: "Use AppColors.accent")
    static let accent600 = accent
    @available(*, deprecated, renamed: "accent", message: "Use AppColors.accent")
    static let accent400 = accent
}

struct AppStrings {
    static func isArabicLocale(_ lang: LanguageManager) -> Bool {
        lang.isArabicEffective
    }

    static func homeTitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "الصفحة الرئيسية" : "Home" }
    static func settingsTitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "الإعدادات" : "Settings" }
    static func appTagline(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "حرر نفسك من إدمان الإنترنت" : "Free yourself from internet addiction" }
    static func createList(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "أنشئ قائمة" : "Create List" }
    static func homeSubtitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "سيطر على حياتك الرقمية" : "Take control of your digital life" }
    static func heroTitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "حرر نفسك" : "Free Your Self" }
    static func createBlocklistTitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "أنشئ قائمة حجب" : "Create Blocklist" }
    static func createBlocklistDesc(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "احجب التطبيقات والمواقع المشتتة" : "Block distracting apps & websites" }
    static func viewAll(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "عرض الكل" : "View All" }
    static func permissionsTitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "الأذونات المطلوبة" : "Permissions required" }
    static func enableNotifications(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "تفعيل الإشعارات" : "Enable Notifications" }
    static func levelLabel(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "المستوى" : "Level" }
    static func challengesLabel(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "التحديات" : "Challenges" }
    static func shareProgress(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "مشاركة التقدّم" : "Share Progress" }
    static func progressTitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "التقدّم" : "Progress" }
    static func progressDesc(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "ابدأ تحدّياً لتحقق سلسلة وترفع مستواك." : "Start a challenge to build streaks and level up." }
}
