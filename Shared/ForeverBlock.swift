import Foundation
import os

/// "Block Forever": a free, permanent filter for porn, gambling and dating.
/// Turning it off needs a 360-day wait from the moment the user asks, or the partner's PIN.
/// Persisted in the App Group so the extensions keep enforcing it without the app.
struct ForeverBlock: Codable, Equatable, Sendable {
    static let unlockWaitDays = 360

    var isEnabled = false
    var enabledAt: Date?
    /// Also caps App Store ratings at 12+, which hides every 17+ app (most dating and gambling apps).
    var blocksMatureApps = false
    var unlockRequestedAt: Date?

    var unlockDate: Date? {
        unlockRequestedAt.map { $0.addingTimeInterval(TimeInterval(Self.unlockWaitDays) * 86_400) }
    }

    /// Enabled and the requested 360-day wait (if any) hasn't finished yet.
    func isActive(at date: Date) -> Bool {
        guard isEnabled else { return false }
        if let unlockDate, unlockDate <= date { return false }
        return true
    }

    /// Gambling and dating sites blocked on top of Apple's adult content filter.
    /// Kept to 25 because the web filter accepts 50 domains in total, shared with the lists.
    static let blockedDomains: [String] = [
        // Gambling
        "bet365.com", "1xbet.com", "stake.com", "betway.com", "williamhill.com", "pokerstars.com",
        "draftkings.com", "fanduel.com", "betfair.com", "melbet.com", "parimatch.com", "888casino.com",
        // Dating
        "tinder.com", "bumble.com", "badoo.com", "hinge.co", "okcupid.com", "match.com", "pof.com",
        "grindr.com", "happn.com", "muzz.com", "eharmony.com", "ashleymadison.com", "adultfriendfinder.com",
    ]
}

enum ForeverBlockRepository {
    private static let logger = Logger(subsystem: "app.samla", category: "ForeverBlock")

    static var fileURL: URL {
        AppGroup.containerURL.appendingPathComponent("forever-block.json")
    }

    static func load() -> ForeverBlock {
        guard let data = try? Data(contentsOf: fileURL) else { return ForeverBlock() }
        do {
            return try JSONDecoder().decode(ForeverBlock.self, from: data)
        } catch {
            logger.error("Failed to decode forever block: \(error.localizedDescription)")
            return ForeverBlock()
        }
    }

    static func save(_ block: ForeverBlock) {
        do {
            let data = try JSONEncoder().encode(block)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            logger.error("Failed to save forever block: \(error.localizedDescription)")
        }
    }
}
