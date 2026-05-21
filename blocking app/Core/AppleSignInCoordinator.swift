//
//  AppleSignInCoordinator.swift
//  blocking app
//
//  Sign in with Apple flow + nonce hashing. Persists the user identifier in the Keychain.
//
//  Setup:
//  1. Enable the "Sign In with Apple" capability in your Xcode target.
//  2. Add `com.apple.developer.applesignin` to your entitlements (the SwiftUI button does
//     not need any further configuration to present the sheet).
//

import AuthenticationServices
import CryptoKit
import Foundation
import os

@MainActor
final class AppleSignInCoordinator: NSObject, ObservableObject {
    static let shared = AppleSignInCoordinator()

    @Published private(set) var isSignedIn: Bool = (KeychainStore.get(.appleUserID) != nil)
    @Published private(set) var lastError: String?

    private var currentNonce: String?
    private let log = Logger(subsystem: "app.nonet.blocking", category: "AppleSignIn")

    private override init() { super.init() }

    /// Configure an ASAuthorizationAppleIDRequest (call this from the SwiftUI `SignInWithAppleButton.onRequest`).
    func configure(request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the completion result (call this from `SignInWithAppleButton.onCompletion`).
    func handle(result: Result<ASAuthorization, Error>) -> Bool {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                lastError = "Unexpected credential type"
                return false
            }
            KeychainStore.set(credential.user, for: .appleUserID)
            isSignedIn = true
            currentNonce = nil
            return true
        case .failure(let error):
            log.error("Sign in with Apple failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            return false
        }
    }

    func signOut() {
        KeychainStore.remove(.appleUserID)
        isSignedIn = false
    }

    // MARK: - Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
