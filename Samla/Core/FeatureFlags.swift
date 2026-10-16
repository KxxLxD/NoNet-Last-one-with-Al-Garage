import Foundation

/// Compile-time switches for features that are built but not shipped yet.
enum FeatureFlags {
    /// Paid Premium. Off for v1: Premium shows as "coming soon" and the free version holds 3 lists.
    static let subscriptionsEnabled = false
}
