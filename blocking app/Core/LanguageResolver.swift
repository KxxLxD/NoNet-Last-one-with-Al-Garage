//
//  LanguageResolver.swift
//  blocking app
//
//  Single source of truth for resolving the effective UI language from
//  storage + locale. Lives in Core/ so non-SwiftUI modules (e.g.
//  SmartListSeeder) can read the same setting LanguageManager exposes
//  to views, without importing SwiftUI or the LanguageManager class.
//
//  Resolution order matches LanguageManager.isArabicEffective:
//    1. UserDefaults["AppLanguage"] explicit user choice ("arabic" /
//       "english"), set via LanguageManager.updateLanguage.
//    2. Locale.preferredLanguages.first for the "system" fallback (or
//       when no choice has been recorded yet).
//

import Foundation

enum LanguageResolver {
    /// The UserDefaults key LanguageManager writes through. Both ends of
    /// the resolver must agree on this constant — if either drifts, the
    /// app and Core/ helpers would silently disagree about language.
    static let storageKey = "AppLanguage"

    /// True when the effective UI language is Arabic. Reads UserDefaults
    /// directly (no actor isolation) so it's callable from any context.
    static func isArabicEffective() -> Bool {
        if let raw = UserDefaults.standard.string(forKey: storageKey) {
            switch raw {
            case "arabic": return true
            case "english": return false
            default: break // "system" or unknown → locale fallback below
            }
        }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("ar")
    }
}
