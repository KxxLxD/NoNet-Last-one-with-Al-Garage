//
//  SmartListSeeder.swift
//  blocking app
//
//  Materializes a user's first BlockingList from the goals + addictive-source
//  selections they gave during onboarding. Pure data transformation — does NOT
//  activate the list (no shields applied). The user opens Home, sees the
//  ready-made list, and taps the explicit Activate button when they're ready.
//
//  Why inactive instead of auto-active:
//  Auto-activating shields without an explicit tap that says "block these apps
//  now" is the kind of friction-via-decision that Apple HIG 2.5.4 flags and
//  that we saw raised in the outside-voice review. The magic-moment value
//  (zero-input first list) is preserved; the consent is moved one tap forward.
//
//  Why we don't gate on a non-empty FamilyActivitySelection:
//  Onboarding collects *intent* (which apps to fight), not the opaque tokens
//  required for actual shielding. The user still has to pass through
//  BlockItemsEditorView once to grant Screen Time and pick the matching apps
//  via FamilyActivityPicker — there's no way around that. What we *can* skip
//  is the create-from-scratch step: name, type, breaks, protection. That's
//  the win this delivers.
//

import Foundation
import CoreData
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "SmartListSeeder")

enum SmartListSeeder {
    /// AppStorage flag so the seeder only fires once per user.
    private static let seededKey = "v1:smartListSeeded"

    /// Inspect onboarding selections and, if there's enough intent expressed,
    /// create one inactive ListEntity matching the user's stated goal.
    /// Idempotent — safe to call on every onboarding completion.
    @MainActor
    static func seedIfNeeded(in context: NSManagedObjectContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }

        let obApps = defaults.string(forKey: AppStorageKeys.obApps) ?? ""
        let obCats = defaults.string(forKey: AppStorageKeys.obCats) ?? ""
        let obGoals = defaults.string(forKey: AppStorageKeys.obGoals) ?? ""

        // If the user picked literally nothing addictive, there's no foothold for a
        // sensible default name and we'd just be creating clutter. Bail out — they'll
        // hit Create-New from Home with a clear blank slate.
        let appsCount = obApps.split(separator: ",").filter { !$0.isEmpty }.count
        let catsCount = obCats.split(separator: ",").filter { !$0.isEmpty }.count
        guard appsCount > 0 || catsCount > 0 else {
            log.notice("seedIfNeeded skipped: no apps or categories selected during onboarding")
            defaults.set(true, forKey: seededKey)
            return
        }

        let listName = goalDrivenName(goalsCSV: obGoals, isArabic: currentLanguageIsArabic())

        let entity = ListEntity(context: context)
        entity.id = UUID()
        entity.name = listName
        entity.protection = "noProtection"
        // "now" is the safest default — no DeviceActivity scheduling required, no
        // BlockingMonitor dependency, no surprises if the extension isn't bound yet.
        // The user can convert to Scheduled / TimeLimit / Forever afterwards.
        entity.blockType = "now"
        entity.durationSeconds = BlockingConstants.seederDefaultDurationSeconds
        entity.createdAt = Date()
        entity.updatedAt = Date()

        switch context.saveIfNeeded() {
        case .success:
            log.notice("smart list seeded: \(listName, privacy: .public) (\(entity.id, privacy: .public))")
            defaults.set(true, forKey: seededKey)
        case .failure(let err):
            log.error("smart list save failed: \(err.localizedDescription, privacy: .public)")
            // Leave seededKey false so a future onboarding completion can retry.
        }
    }

    /// Map the user's stated goal codes to a human-readable Arabic / English
    /// list name. Picks the strongest single goal — most users select 2-3 and a
    /// list name carrying all of them is unwieldy.
    private static func goalDrivenName(goalsCSV: String, isArabic: Bool) -> String {
        let goals = Set(goalsCSV.split(separator: ",").map { String($0) })

        if goals.contains("better_sleep") {
            return isArabic ? "وقت النوم" : "Sleep Time"
        }
        if goals.contains("improve_focus") || goals.contains("increase_productivity") {
            return isArabic ? "وقت التركيز" : "Focus Time"
        }
        if goals.contains("work_performance") {
            return isArabic ? "وقت العمل" : "Work Time"
        }
        if goals.contains("academic_performance") {
            return isArabic ? "وقت الدراسة" : "Study Time"
        }
        if goals.contains("reduce_shorts") || goals.contains("less_screen") {
            return isArabic ? "تقليل وقت الشاشة" : "Less Screen Time"
        }
        if goals.contains("quit_adult") {
            return isArabic ? "تجنب المحتوى الإباحي" : "Adult Content Block"
        }
        if goals.contains("quit_gambling") {
            return isArabic ? "تجنب القمار" : "Gambling Block"
        }
        if goals.contains("reduce_shopping") {
            return isArabic ? "تقليل التسوق" : "Less Shopping"
        }
        return isArabic ? "قائمتي الأولى" : "My First List"
    }

    /// Read LanguageManager's effective state without importing it here (this
    /// file stays Core/-pure and doesn't depend on SwiftUI views). Mirrors the
    /// resolution order in LanguageManager.isArabicEffective: explicit user
    /// choice (LanguageOption raw value) first, then system locale fallback.
    ///
    /// Key + values must match `LanguageManager` exactly:
    /// - Key: "AppLanguage" (Theme.swift:27,36)
    /// - Values: "system" / "arabic" / "english"
    private static func currentLanguageIsArabic() -> Bool {
        if let stored = UserDefaults.standard.string(forKey: "AppLanguage") {
            switch stored {
            case "arabic": return true
            case "english": return false
            default: break // "system" or unknown → fall through to locale
            }
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ar")
    }
}
