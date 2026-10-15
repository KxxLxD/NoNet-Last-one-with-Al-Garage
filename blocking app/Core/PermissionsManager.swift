//
//  PermissionsManager.swift
//  blocking app
//
//  Centralized handling for Screen Time (FamilyControls) and Notifications.
//  Re-checks state when the app comes back to the foreground.
//

import SwiftUI
import FamilyControls
import UserNotifications
import os

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    enum ScreenTimeStatus: Equatable {
        case unknown
        case granted
        case denied
        case notDetermined
    }

    enum NotificationsStatus: Equatable {
        case unknown
        case authorized
        case denied
        case notDetermined
        case provisional
    }

    @Published private(set) var screenTime: ScreenTimeStatus = .unknown
    @Published private(set) var notifications: NotificationsStatus = .unknown

    private let log = Logger(subsystem: "app.nonet.blocking", category: "Permissions")
    private var didStartObserving = false

    private init() {}

    /// Start observing app lifecycle and load current state once.
    func bootstrap() {
        if !didStartObserving {
            didStartObserving = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleForeground),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
        Task { await refresh() }
    }

    var isScreenTimeGranted: Bool { screenTime == .granted }
    var isNotificationsGranted: Bool { notifications == .authorized || notifications == .provisional }

    func refresh() async {
        await refreshScreenTime()
        await refreshNotifications()
    }

    // MARK: - Screen Time
    func refreshScreenTime() async {
        let status = AuthorizationCenter.shared.authorizationStatus
        switch status {
        case .approved: screenTime = .granted
        case .denied: screenTime = .denied
        case .notDetermined: screenTime = .notDetermined
        @unknown default: screenTime = .unknown
        }
    }

    /// Request Screen Time authorization. No-op if already granted.
    func requestScreenTime() async {
        guard screenTime != .granted else { return }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await refreshScreenTime()
        } catch {
            log.error("Screen Time auth failed: \(error.localizedDescription, privacy: .public)")
            await refreshScreenTime()
        }
    }

    // MARK: - Notifications
    func refreshNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: notifications = .authorized
        case .denied: notifications = .denied
        case .notDetermined: notifications = .notDetermined
        case .provisional: notifications = .provisional
        case .ephemeral: notifications = .authorized
        @unknown default: notifications = .unknown
        }
    }

    /// Request Notifications authorization. No-op if already authorized.
    /// If user denied earlier, opens iOS Settings instead.
    func requestNotifications(openSettingsIfDenied: Bool = true) async {
        await refreshNotifications()
        switch notifications {
        case .authorized, .provisional:
            return
        case .denied:
            if openSettingsIfDenied { openAppSettings() }
            return
        default:
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                log.error("Notifications auth failed: \(error.localizedDescription, privacy: .public)")
            }
            await refreshNotifications()
        }
    }

    /// Open Settings.app to the current app's privacy page so a user can change a "Denied" decision.
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func handleForeground() {
        Task { await refresh() }
    }
}
