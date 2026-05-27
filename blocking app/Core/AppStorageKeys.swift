//
//  AppStorageKeys.swift
//  blocking app
//
//  Single source of truth for all @AppStorage keys.
//  Use the static constants directly (e.g. `@AppStorage(AppStorageKeys.isPremium)`).
//

import Foundation

enum AppStorageKeys {
    // Every key carries the `v1:` schema-version prefix. Pre-v1 installations
    // get migrated to this naming in `PersistenceMigration.runIfNeeded()`.

    // Auth & onboarding
    static let isAuthenticated = "v1:isAuthenticated"
    static let showOnboardingAfterLogin = "v1:showOnboardingAfterLogin"

    // Subscription / trial
    static let isPremium = "v1:isPremium"
    static let trialStartTs = "v1:trialStartTs"
    static let hasShownTrialExpiredAlert = "v1:hasShownTrialExpiredAlert"

    // Role marker for DEBUG-only admin/QA flows (admin login in AuthView,
    // admin-only Settings section). Never set in Release builds.
    static let isAdmin = "v1:isAdmin"

    // UI state
    static let selectedTab = "v1:selectedTab"
    static let permissionsExpanded = "v1:permissionsExpanded"

    // Onboarding profile
    static let obName = "v1:obName"
    static let obGender = "v1:obGender"
    static let obAgeGroup = "v1:obAgeGroup"
    static let obApps = "v1:obApps"
    static let obAppsOther = "v1:obAppsOther"
    static let obCats = "v1:obCats"
    static let obCatsOther = "v1:obCatsOther"
    static let obGoals = "v1:obGoals"
    static let obGoalsOther = "v1:obGoalsOther"

    // Seed bookkeeping
    static let seedV1Done = "v1:seedDone"

    // ChatBot free-tier rate limiting (resets at midnight per-device)
    static let chatFreeMessagesUsedToday = "v1:chat:freeMessagesUsedToday"
    static let chatFreeMessagesLastDayKey = "v1:chat:freeMessagesLastDayKey"

    // ChatBot persistence — last N messages serialized as JSON so the
    // conversation survives app restarts. The list is hard-capped at
    // ChatBotView.maxPersistedMessages to prevent UserDefaults bloat.
    static let chatMessagesJSON = "v1:chat:messagesJSON"

    // Challenges gamification — cumulative points earned. Level is derived
    // from this via BlockingConstants.challengePointsPerLevel.
    static let challengeTotalPoints = "v1:challenges:totalPoints"
}
