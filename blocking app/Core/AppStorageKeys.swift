//
//  AppStorageKeys.swift
//  blocking app
//
//  Single source of truth for all @AppStorage keys.
//  Use the static constants directly (e.g. `@AppStorage(AppStorageKeys.isPremium)`).
//

import Foundation

enum AppStorageKeys {
    // Auth & onboarding
    static let isAuthenticated = "isAuthenticated"
    static let showOnboardingAfterLogin = "showOnboardingAfterLogin"

    // Subscription / trial
    static let isPremium = "isPremium"
    static let trialStartTs = "trialStartTs"
    static let hasShownTrialExpiredAlert = "hasShownTrialExpiredAlert"

    // Role marker for DEBUG-only admin/QA flows (admin login in AuthView,
    // admin-only Settings section). Never set in Release builds.
    static let isAdmin = "v1:isAdmin"

    // UI state
    static let selectedTab = "selectedTab"
    static let permissionsExpanded = "v1:permissionsExpanded"

    // Onboarding profile
    static let obName = "ob_name"
    static let obGender = "ob_gender"
    static let obAgeGroup = "ob_age_group"
    static let obApps = "ob_apps"
    static let obAppsOther = "ob_apps_other"
    static let obCats = "ob_cats"
    static let obCatsOther = "ob_cats_other"
    static let obGoals = "ob_goals"
    static let obGoalsOther = "ob_goals_other"

    // Seed bookkeeping
    static let seedV1Done = "seed_v1_done"

    // ChatBot free-tier rate limiting (resets at midnight per-device)
    static let chatFreeMessagesUsedToday = "v1:chat:freeMessagesUsedToday"
    static let chatFreeMessagesLastDayKey = "v1:chat:freeMessagesLastDayKey"

    // ChatBot persistence — last N messages serialized as JSON so the
    // conversation survives app restarts. The list is hard-capped at
    // ChatBotView.maxPersistedMessages to prevent UserDefaults bloat.
    static let chatMessagesJSON = "v1:chat:messagesJSON"
}
