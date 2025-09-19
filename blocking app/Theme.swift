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

struct AppColors {
    static let primaryBlue = Color(red: 37/255, green: 99/255, blue: 235/255)
    static let alertRed = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let successGreen = Color(red: 16/255, green: 185/255, blue: 129/255)
    // UI-Mode tokens
    static let uiBackground = Color(red: 243/255, green: 244/255, blue: 246/255) // #F3F4F6
    static let uiSurface = Color.white // #FFFFFF
    static let uiBorder = Color(red: 229/255, green: 231/255, blue: 235/255) // #E5E7EB
    // Precise tokens
    static let accent400 = Color(red: 96/255, green: 165/255, blue: 250/255) // #60A5FA
    static let accent600 = Color(red: 37/255, green: 99/255, blue: 235/255) // #2563EB
    // Custom gradient palette
    static let accentLight = Color(red: 140/255, green: 188/255, blue: 252/255) // #8CBCFC
    static let accentDark  = Color(red: 77/255,  green: 162/255, blue: 252/255) // #4DA2FC
    static let textPrimary = Color(red: 55/255, green: 65/255, blue: 81/255) // #374151
    static let textSecondary = Color(red: 107/255, green: 114/255, blue: 128/255) // #6B7280
    static let infoBg = Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.1) // #2563EB1A
    static let infoFg = Color(red: 37/255, green: 99/255, blue: 235/255) // #2563EB
    static let warningBg = Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.1) // #F59E0B1A
    static let warningFg = Color(red: 245/255, green: 158/255, blue: 11/255) // #F59E0B
    // Calm trophy gold for achievements
    static let trophyGold = Color(red: 212/255, green: 175/255, blue: 55/255) // #D4AF37
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
    static func createBlocklistTitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "أنشئ قائمة حظر" : "Create Blocklist" }
    static func createBlocklistDesc(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "احظر التطبيقات والمواقع المشتتة" : "Block distracting apps & websites" }
    static func viewAll(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "عرض الكل" : "View All" }
    static func permissionsTitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "الأذونات المطلوبة" : "Permissions required" }
    static func enableNotifications(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "تفعيل الإشعارات" : "Enable Notifications" }
    static func levelLabel(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "المستوى" : "Level" }
    static func challengesLabel(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "التحديات" : "Challenges" }
    static func shareProgress(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "مشاركة التقدّم" : "Share Progress" }
    static func progressTitle(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "التقدّم" : "Progress" }
    static func progressDesc(_ lang: LanguageManager) -> String { isArabicLocale(lang) ? "ابدأ تحدّيًا لتحقق سلسلة وترفع مستواك." : "Start a challenge to build streaks and level up." }
}
