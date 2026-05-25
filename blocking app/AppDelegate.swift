//
//  AppDelegate.swift
//  blocking app
//
//  SwiftUI app's UIApplicationDelegate hook. Exists for two reasons:
//
//  1. CloudKit share acceptance — when a partner taps the invitation link
//     iOS routes the CKShare.Metadata through this delegate (no equivalent
//     pure-SwiftUI API exists). We forward to CloudKitPartnerStore.
//  2. Scene configuration — must register a SceneDelegate so the iOS-15+
//     scene callback `windowScene(_:userDidAcceptCloudKitShareWith:)` is
//     invoked. Without this, the share-acceptance handler never fires.
//

import UIKit
import CloudKit
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "AppDelegate")

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = PartnerSceneDelegate.self
        return config
    }

    /// Register for silent push notifications. Required for CloudKit
    /// `CKQuerySubscription` callbacks to reach the device when a Recovery
    /// Partner break-attempt record is created on another device — without
    /// this, the partner's device only sees new attempts on next foreground
    /// of the app (defeating the "real-time accountability" of the feature).
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    /// APNs successfully registered the device. CloudKit subscriptions don't
    /// require us to forward the token to a backend (CloudKit registers via
    /// its own internal mechanism), but logging confirms the push pipeline
    /// is healthy end-to-end.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        log.notice("APNs registration succeeded (token length: \(tokenString.count, privacy: .public))")
    }

    /// APNs registration failed — usually because the device is on Simulator
    /// (no entitlement support) or has no internet at launch. Non-fatal:
    /// CloudKit retries on its own subscription registration cadence and the
    /// PendingBreakAttemptQueue covers offline gaps.
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }

    /// Silent push delivery. NoNet pushes are CloudKit subscription
    /// notifications about new `BreakAttempt` records on the partner's
    /// device. Hand off to CloudKit and let the store refresh.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        log.notice("Received CloudKit push notification")
        Task { @MainActor in
            await CloudKitPartnerStore.shared.fetchPartnerships()
            await CloudKitPartnerStore.shared.flushPendingBreakAttempts()
            completionHandler(.newData)
        }
    }
}

/// Minimal scene delegate whose only job is to receive `userDidAcceptCloudKitShareWith`.
/// SwiftUI's lifecycle handles the rest (windows, view hierarchy, environment).
final class PartnerSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        log.notice("scene received CKShare.Metadata for \(cloudKitShareMetadata.share.recordID.recordName, privacy: .public)")
        Task { @MainActor in
            await CloudKitPartnerStore.shared.acceptInvitation(metadata: cloudKitShareMetadata)
        }
    }
}
