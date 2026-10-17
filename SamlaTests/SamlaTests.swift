import Foundation
import Testing
@testable import Samla

/// A fixed Gregorian/UTC calendar so schedule tests don't depend on the device.
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

/// 0 = Sunday … 6 = Saturday, matching `ScheduleSlot.day`.
private func weekday(of date: Date) -> Int {
    calendar.component(.weekday, from: date) - 1
}

// MARK: - Schedule

@Suite("Schedule slots")
struct ScheduleSlotTests {
    @Test func daytimeSlotContainsOnlyItsWindow() {
        let slot = ScheduleSlot(day: 1, fromMinutes: 9 * 60, toMinutes: 17 * 60)
        #expect(slot.contains(day: 1, minute: 9 * 60))
        #expect(slot.contains(day: 1, minute: 16 * 60 + 59))
        #expect(!slot.contains(day: 1, minute: 17 * 60))
        #expect(!slot.contains(day: 2, minute: 10 * 60))
        #expect(slot.durationMinutes == 8 * 60)
    }

    @Test func overnightSlotRunsIntoTheNextDay() {
        let slot = ScheduleSlot(day: 6, fromMinutes: 22 * 60, toMinutes: 6 * 60)
        #expect(slot.isOvernight)
        #expect(slot.durationMinutes == 8 * 60)
        #expect(slot.contains(day: 6, minute: 23 * 60))
        #expect(slot.contains(day: 0, minute: 5 * 60)) // Saturday night wraps to Sunday
        #expect(!slot.contains(day: 0, minute: 7 * 60))
    }
}

@Suite("Block lists")
struct BlockListTests {
    @Test func blockNowIsActiveOnlyDuringItsSession() {
        let start = date(2026, 10, 17, 10)
        var list = BlockList(name: "Focus")
        list.session = DateInterval(start: start, duration: 3600)
        #expect(list.isActive(at: start.addingTimeInterval(60), calendar: calendar))
        #expect(!list.isActive(at: start.addingTimeInterval(3601), calendar: calendar))
        #expect(list.activeUntil(at: start.addingTimeInterval(60), calendar: calendar) == start.addingTimeInterval(3600))
    }

    @Test func overnightScheduleEndsTomorrowMorning() {
        let night = date(2026, 10, 17, 23)
        var list = BlockList(name: "Sleep")
        list.kind = .scheduled
        list.slots = [ScheduleSlot(day: weekday(of: night), fromMinutes: 22 * 60, toMinutes: 6 * 60)]
        #expect(list.isActive(at: night, calendar: calendar))
        #expect(list.activeUntil(at: night, calendar: calendar) == date(2026, 10, 18, 6))
    }

    @Test func nextStartTodayFindsTheUpcomingSlot() {
        let morning = date(2026, 10, 17, 8)
        var list = BlockList(name: "Sleep")
        list.kind = .scheduled
        list.slots = [ScheduleSlot(day: weekday(of: morning), fromMinutes: 22 * 60, toMinutes: 6 * 60)]
        #expect(list.nextStartToday(after: morning, calendar: calendar) == date(2026, 10, 17, 22))
        #expect(list.nextStartToday(after: date(2026, 10, 17, 23), calendar: calendar) == nil) // already active
    }

    @Test func hardModeAllowsNoBreaks() {
        var list = BlockList(name: "Hard")
        list.breaks = BreakPolicy(count: 3, minutes: 10)
        list.protection = .hard
        #expect(!list.allowsBreaks)
        #expect(list.breaksRemaining(at: .now) == 0)
    }

    @Test func breaksResetAfter24Hours() {
        let now = date(2026, 10, 17, 12)
        var list = BlockList(name: "Breaks")
        list.breaks = BreakPolicy(count: 2, minutes: 5)
        list.breakStarts = [now.addingTimeInterval(-3600), now.addingTimeInterval(-25 * 3600)]
        #expect(list.breaksRemaining(at: now) == 1)
    }

    @Test func protectedListsLockOnlyWhileActive() {
        let start = date(2026, 10, 17, 10)
        var list = BlockList(name: "Partner")
        list.protection = .partner
        list.session = DateInterval(start: start, duration: 3600)
        #expect(list.isLocked(at: start.addingTimeInterval(60)))
        #expect(!list.isLocked(at: start.addingTimeInterval(7200)))
    }
}

// MARK: - Block Forever

@Suite("Block Forever")
struct ForeverBlockTests {
    @Test func staysActiveUntil360DaysAfterTheUnlockRequest() {
        let requested = date(2026, 1, 1, 12)
        let block = ForeverBlock(isEnabled: true, enabledAt: requested, blocksMatureApps: false, unlockRequestedAt: requested)
        #expect(block.unlockDate == requested.addingTimeInterval(360 * 86_400))
        #expect(block.isActive(at: requested.addingTimeInterval(359 * 86_400)))
        #expect(!block.isActive(at: requested.addingTimeInterval(360 * 86_400)))
    }

    @Test func disabledBlockIsNeverActive() {
        #expect(!ForeverBlock().isActive(at: .now))
    }

    @Test func blockedDomainsLeaveRoomForUserWebsites() {
        // The web filter accepts 50 domains in total, shared with the lists.
        #expect(ForeverBlock.blockedDomains.count <= 25)
        #expect(Set(ForeverBlock.blockedDomains).count == ForeverBlock.blockedDomains.count)
    }
}

// MARK: - Partner PIN

@Suite("Partner PIN", .serialized)
struct PartnerStoreTests {
    private func makeStore() -> PartnerStore {
        let defaults = UserDefaults(suiteName: "SamlaTests.partner")!
        defaults.removePersistentDomain(forName: "SamlaTests.partner")
        let store = PartnerStore(defaults: defaults)
        store.remove()
        return store
    }

    @Test func onlyFourDigitPINsAreValid() {
        #expect(PartnerStore.isValidPIN("1234"))
        #expect(!PartnerStore.isValidPIN("123"))
        #expect(!PartnerStore.isValidPIN("12345"))
        #expect(!PartnerStore.isValidPIN("12a4"))
    }

    @Test func correctPINSucceedsAndWrongPINCountsDown() {
        let store = makeStore()
        defer { store.remove() }
        store.setPartner(name: "Ahmed", pin: "4821")
        #expect(store.hasPartner)
        #expect(store.verify("4821") == .success)
        #expect(store.verify("0000") == .wrong(attemptsLeft: 4))
    }

    @Test func fiveWrongAttemptsLockOut() {
        let store = makeStore()
        defer { store.remove() }
        store.setPartner(name: "Ahmed", pin: "4821")
        let now = Date.now
        for _ in 0..<4 { _ = store.verify("0000", now: now) }
        guard case .lockedOut = store.verify("0000", now: now) else {
            Issue.record("Expected a lockout after five wrong PINs")
            return
        }
        // Even the right PIN is refused during the lockout.
        guard case .lockedOut = store.verify("4821", now: now) else {
            Issue.record("Expected the lockout to hold")
            return
        }
    }

    @Test func forgotPINRemovesThePartnerAfterSevenDays() {
        let store = makeStore()
        defer { store.remove() }
        store.setPartner(name: "Ahmed", pin: "4821")
        let requested = Date.now
        store.requestForgotReset(now: requested)
        store.resolveForgotReset(now: requested.addingTimeInterval(6 * 86_400))
        #expect(store.hasPartner)
        store.resolveForgotReset(now: requested.addingTimeInterval(7 * 86_400))
        #expect(!store.hasPartner)
    }
}

// MARK: - Input & formatting

@Suite("Website input")
struct WebsiteInputTests {
    @Test(arguments: [
        ("https://www.YouTube.com/watch?v=1", "youtube.com"),
        ("tiktok.com", "tiktok.com"),
        ("  shahid.mbc.net/  ", "shahid.mbc.net"),
    ])
    func normalizesToABareDomain(input: String, expected: String) {
        #expect(WebsiteInput.normalize(input) == expected)
    }

    @Test(arguments: ["youtube", "not a site", ".com", "example."])
    func rejectsNonDomains(input: String) {
        #expect(WebsiteInput.normalize(input) == nil)
    }
}

@Suite("Western digits")
struct AppLocaleTests {
    @Test func numbersUseWesternDigits() {
        #expect(360.formatted(.number.locale(.app)) == "360")
    }
}

// MARK: - Safety & localization

@Suite("Start confirmation")
struct StartConfirmationTests {
    @Test(arguments: [(ProtectionMode.none, false), (.hard, true), (.partner, true)])
    func onlyProtectedListsAskBeforeStarting(protection: ProtectionMode, asks: Bool) {
        var list = BlockList(name: "Focus")
        list.protection = protection
        #expect(list.startNeedsConfirmation == asks)
    }
}

@Suite("Localization")
struct LocalizationTests {
    /// Arabic is the main audience: no string may fall back to English.
    @Test func everyStringHasAnArabicTranslation() throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Samla/Resources/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = try #require(catalog?["strings"] as? [String: [String: Any]])
        let missing = strings.filter { _, entry in
            guard entry["shouldTranslate"] as? Bool != false,
                  entry["extractionState"] as? String != "stale" else { return false }
            let arabic = (entry["localizations"] as? [String: Any])?["ar"] as? [String: Any]
            return arabic?["stringUnit"] == nil && arabic?["variations"] == nil
        }
        #expect(missing.isEmpty, "Missing Arabic: \(missing.keys.sorted())")
    }
}
