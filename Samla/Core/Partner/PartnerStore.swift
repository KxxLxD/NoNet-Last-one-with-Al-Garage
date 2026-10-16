import CryptoKit
import Foundation
import Observation

/// The single accountability partner: a name plus a 4-digit PIN the partner types in themselves.
/// The PIN is stored as a salted SHA-256 hash in the Keychain, and wrong guesses are rate-limited
/// so a short PIN can't be brute-forced.
@Observable
final class PartnerStore {
    enum VerifyResult: Equatable {
        case success
        case wrong(attemptsLeft: Int)
        case lockedOut(until: Date)
    }

    static let pinLength = 4
    /// "Forgot PIN" removes the partner after this wait (Block Forever keeps its own 360 days).
    static let forgotWaitDays = 7
    private static let maxAttempts = 5
    private static let lockoutDuration: TimeInterval = 15 * 60

    private(set) var name: String?
    private(set) var hasPIN: Bool
    private(set) var forgotRequestedAt: Date?

    var hasPartner: Bool { hasPIN }

    var forgotResetDate: Date? {
        forgotRequestedAt.map { $0.addingTimeInterval(TimeInterval(Self.forgotWaitDays) * 86_400) }
    }

    private let defaults: UserDefaults
    private enum Key {
        static let pin = "partner.pin"
        static let name = "partner.name"
        static let attempts = "partner.attempts"
        static let lockUntil = "partner.lockUntil"
        static let forgotRequestedAt = "partner.forgotRequestedAt"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        name = defaults.string(forKey: Key.name)
        hasPIN = Keychain.string(for: Key.pin) != nil
        forgotRequestedAt = defaults.object(forKey: Key.forgotRequestedAt) as? Date
        resolveForgotReset()
    }

    static func isValidPIN(_ pin: String) -> Bool {
        pin.count == pinLength && pin.allSatisfy(\.isASCIIDigit)
    }

    func setPartner(name: String, pin: String) {
        let salt = UUID().uuidString
        Keychain.set("\(salt):\(Self.hash(pin, salt: salt))", for: Key.pin)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmed
        defaults.set(trimmed, forKey: Key.name)
        hasPIN = true
        resetAttempts()
        cancelForgotReset()
    }

    func verify(_ pin: String, now: Date = .now) -> VerifyResult {
        if let until = defaults.object(forKey: Key.lockUntil) as? Date, until > now {
            return .lockedOut(until: until)
        }
        // No stored PIN (e.g. the Keychain didn't survive a device restore): don't trap the user.
        guard let stored = Keychain.string(for: Key.pin),
              let separator = stored.firstIndex(of: ":") else { return .success }
        let salt = String(stored[..<separator])
        let expected = String(stored[stored.index(after: separator)...])

        if Self.hash(pin, salt: salt) == expected {
            resetAttempts()
            return .success
        }

        let attempts = defaults.integer(forKey: Key.attempts) + 1
        if attempts >= Self.maxAttempts {
            let until = now.addingTimeInterval(Self.lockoutDuration)
            defaults.set(until, forKey: Key.lockUntil)
            defaults.set(0, forKey: Key.attempts)
            return .lockedOut(until: until)
        }
        defaults.set(attempts, forKey: Key.attempts)
        return .wrong(attemptsLeft: Self.maxAttempts - attempts)
    }

    /// Callers must verify the current PIN first (or let the forgot-PIN wait finish).
    func remove() {
        Keychain.remove(Key.pin)
        defaults.removeObject(forKey: Key.name)
        name = nil
        hasPIN = false
        resetAttempts()
        cancelForgotReset()
    }

    // MARK: - Forgot PIN

    func requestForgotReset(now: Date = .now) {
        forgotRequestedAt = now
        defaults.set(now, forKey: Key.forgotRequestedAt)
    }

    func cancelForgotReset() {
        forgotRequestedAt = nil
        defaults.removeObject(forKey: Key.forgotRequestedAt)
    }

    /// Removes the partner once the forgot-PIN wait is over. Call whenever the app becomes active.
    func resolveForgotReset(now: Date = .now) {
        guard let date = forgotResetDate, date <= now else { return }
        remove()
    }

    // MARK: - Helpers

    private static func hash(_ pin: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + pin).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func resetAttempts() {
        defaults.removeObject(forKey: Key.attempts)
        defaults.removeObject(forKey: Key.lockUntil)
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
