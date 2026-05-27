//
//  DataReset.swift
//  blocking app
//
//  Centralized sign-out cleanup. Removes everything that should be considered
//  "this user's data" so a different person signing in afterwards on the same
//  device doesn't inherit lists, onboarding answers, trial state, or break
//  history from the previous account.
//
//  CloudKit data is intentionally untouched — partnerships and break attempts
//  live on the iCloud Apple ID and follow the user, not the device. Family
//  Controls authorization is also left alone (per-device, granted to the
//  bundle, not to a logged-in user).
//
//  Hard Mode lists are force-deactivated. Sign-out is an explicit, deliberate
//  intent stronger than the impulse-protection Hard Mode guards against —
//  honouring the lock during sign-out would strand the next user with shields
//  they can't release.
//

import Foundation
import CoreData
import os

@MainActor
enum DataReset {
    private static let log = Logger(subsystem: "app.nonet.blocking", category: "DataReset")

    /// All AppStorage keys that belong to the current user's session. Listed
    /// explicitly (rather than scanning UserDefaults) so newly-added keys
    /// require a conscious decision about whether they survive sign-out.
    private static var userScopedAppStorageKeys: [String] {
        [
            AppStorageKeys.isAuthenticated,
            AppStorageKeys.showOnboardingAfterLogin,
            AppStorageKeys.isPremium,
            AppStorageKeys.trialStartTs,
            AppStorageKeys.hasShownTrialExpiredAlert,
            AppStorageKeys.isAdmin,
            AppStorageKeys.selectedTab,
            AppStorageKeys.permissionsExpanded,
            AppStorageKeys.obName,
            AppStorageKeys.obGender,
            AppStorageKeys.obAgeGroup,
            AppStorageKeys.obApps,
            AppStorageKeys.obAppsOther,
            AppStorageKeys.obCats,
            AppStorageKeys.obCatsOther,
            AppStorageKeys.obGoals,
            AppStorageKeys.obGoalsOther,
            AppStorageKeys.seedV1Done,
            AppStorageKeys.chatFreeMessagesUsedToday,
            AppStorageKeys.chatFreeMessagesLastDayKey,
            AppStorageKeys.chatMessagesJSON,
        ]
    }

    /// Tear down everything tied to the current user and signal logout.
    /// Order matters: shields must be lifted (via BlockingEngine.purge) before
    /// the Core Data rows are deleted, otherwise the ManagedSettingsStore
    /// reference is lost and the shield silently lingers until next launch.
    static func signOutAndClear() {
        log.notice("signOutAndClear: starting tear-down")

        purgeAllLists()
        clearAppStorage()
        clearPerListStores()
        PendingBreakAttemptQueue.clear()
        AppleSignInCoordinator.shared.signOut()

        log.notice("signOutAndClear: complete")
    }

    /// Force-deactivate every blocking list, then delete the Core Data rows.
    /// `purge` also clears the App Group FamilySelectionStore + EmergencyUnlockStore
    /// per list, so no orphaned shield tokens or unlock-request timestamps survive.
    private static func purgeAllLists() {
        let context = CoreDataStack.shared.viewContext
        let fetch: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        do {
            let lists = try context.fetch(fetch)
            for list in lists {
                BlockingEngine.shared.purge(listId: list.id)
                context.delete(list)
            }
            if case .failure(let error) = context.saveIfNeeded() {
                log.error("purgeAllLists save failed: \(error.localizedDescription, privacy: .public)")
            } else {
                log.notice("purgeAllLists: deleted \(lists.count) lists")
            }
        } catch {
            log.error("purgeAllLists fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func clearAppStorage() {
        let defaults = UserDefaults.standard
        for key in userScopedAppStorageKeys {
            defaults.removeObject(forKey: key)
        }
        // DeletionLogStore is a single keyed entry, not per-list — wipe it
        // explicitly so the next user doesn't see the previous user's
        // strong-reason confessions.
        defaults.removeObject(forKey: "v1:deletionLog:entries")
    }

    /// Per-list stores that aren't keyed by Core Data relationships — they
    /// use UUID-derived UserDefaults keys, so they don't disappear with the
    /// Core Data delete. `purgeAllLists` already runs `BlockingEngine.purge`
    /// for each list (which clears their per-list keys), but if a list was
    /// deleted outside the normal flow before sign-out, its keys would
    /// remain. Scan defaults for the per-list key prefixes to catch orphans.
    private static func clearPerListStores() {
        let defaults = UserDefaults.standard
        let prefixes = [
            "v1:manual:",
            "v1:breaks:",
            "v1:emergencyUnlock:",
        ]
        for key in defaults.dictionaryRepresentation().keys {
            if prefixes.contains(where: { key.hasPrefix($0) }) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
