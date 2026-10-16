import Foundation

/// Shared container used by the app and the DeviceActivity monitor extension.
enum AppGroup {
    static let identifier = "group.com.databox.nonet.blocking-app"

    /// Directory shared between the app and its extensions.
    /// Falls back to Application Support when the group container is unavailable (e.g. unsigned builds).
    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }
}
