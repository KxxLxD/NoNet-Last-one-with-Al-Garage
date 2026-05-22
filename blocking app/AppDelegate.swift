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
