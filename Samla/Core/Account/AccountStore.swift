import AuthenticationServices
import Foundation
import Observation

/// Sign in with Apple. Samla has no server, so the "account" is the Apple user identifier
/// kept in the Keychain plus a display name; all app data stays on the device.
@Observable
final class AccountStore {
    private(set) var userID: String?
    private(set) var displayName: String?
    /// The user chose to continue without signing in.
    private(set) var hasSkippedSignIn: Bool

    var isSignedIn: Bool { userID != nil }
    /// Whether the welcome/sign-in screen should still be shown.
    var needsWelcome: Bool { !isSignedIn && !hasSkippedSignIn }

    private let defaults: UserDefaults
    private enum Key {
        static let userID = "account.appleUserID"
        static let displayName = "account.displayName"
        static let skipped = "account.skippedSignIn"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        userID = Keychain.string(for: Key.userID)
        displayName = defaults.string(forKey: Key.displayName)
        hasSkippedSignIn = defaults.bool(forKey: Key.skipped)
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName]
    }

    /// Handles the result of `SignInWithAppleButton`. Returns an error message to show, if any.
    func handle(_ result: Result<ASAuthorization, Error>) -> String? {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return String(localized: "Sign in failed. Please try again.")
            }
            Keychain.set(credential.user, for: Key.userID)
            userID = credential.user
            // Apple only shares the name on the first sign-in; keep what we already have otherwise.
            if let name = credential.fullName.flatMap({ PersonNameComponentsFormatter().string(from: $0) }), !name.isEmpty {
                displayName = name
                defaults.set(name, forKey: Key.displayName)
            }
            setSkipped(false)
            return nil
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return nil }
            return String(localized: "Sign in failed. Please try again.")
        }
    }

    func continueWithoutAccount() {
        setSkipped(true)
    }

    /// Signs out if the user revoked Samla in Settings › Apple Account › Sign in with Apple.
    func verifyCredentialState() async {
        guard let userID else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        if state == .revoked || state == .notFound {
            signOut()
        }
    }

    func signOut() {
        Keychain.remove(Key.userID)
        userID = nil
        setSkipped(false)
    }

    /// Removes the account identity and personal details stored on this device.
    func deleteAccount() {
        Keychain.remove(Key.userID)
        defaults.removeObject(forKey: Key.displayName)
        userID = nil
        displayName = nil
        setSkipped(false)
    }

    private func setSkipped(_ value: Bool) {
        hasSkippedSignIn = value
        defaults.set(value, forKey: Key.skipped)
    }
}
