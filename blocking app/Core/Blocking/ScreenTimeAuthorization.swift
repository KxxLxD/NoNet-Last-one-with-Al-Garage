import FamilyControls
import Observation

/// Tracks whether Samla is allowed to use Screen Time (required for any blocking).
@Observable
final class ScreenTimeAuthorization {
    private(set) var isApproved = false

    init() {
        refresh()
    }

    func refresh() {
        isApproved = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Shows the system Screen Time prompt. Returns `true` once access is granted.
    @discardableResult
    func request() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // User declined or the device can't use Screen Time; status below reflects it.
        }
        refresh()
        return isApproved
    }
}
