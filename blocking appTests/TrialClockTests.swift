//
//  TrialClockTests.swift
//  blocking appTests
//
//  Exercises Core/TrialClock.swift — single source of truth for trial-elapsed
//  math. Critical paths: clock-rewind defense (negative elapsed treated as
//  expired in isTrialActive; signed compare in hasTrialExpired so it doesn't
//  spuriously demote an active trial when the clock moves forward).
//

import XCTest
@testable import blocking_app

final class TrialClockTests: XCTestCase {
    private var trialStartTs: Double!
    private let trialDuration = BlockingConstants.trialDurationSeconds

    override func setUp() {
        super.setUp()
        // Reference start: 2026-01-01 00:00 UTC. The tests then move `now`
        // around that anchor instead of `trialStartTs`, so the clock-rewind
        // scenarios are explicit and the math doesn't depend on Date().
        trialStartTs = 1767225600
    }

    // MARK: - isTrialActive

    func testIsTrialActiveAtStartIsTrue() {
        let now = Date(timeIntervalSince1970: trialStartTs)
        XCTAssertTrue(TrialClock.isTrialActive(startTs: trialStartTs, now: now))
    }

    func testIsTrialActiveMidWindowIsTrue() {
        // Mid-trial: 3 days in (well inside the 7-day window).
        let now = Date(timeIntervalSince1970: trialStartTs + 3 * 86_400)
        XCTAssertTrue(TrialClock.isTrialActive(startTs: trialStartTs, now: now))
    }

    func testIsTrialActiveAtBoundaryIsFalse() {
        // Exactly the duration mark — should be expired.
        let now = Date(timeIntervalSince1970: trialStartTs + trialDuration)
        XCTAssertFalse(TrialClock.isTrialActive(startTs: trialStartTs, now: now))
    }

    func testIsTrialActivePastWindowIsFalse() {
        let now = Date(timeIntervalSince1970: trialStartTs + trialDuration + 1)
        XCTAssertFalse(TrialClock.isTrialActive(startTs: trialStartTs, now: now))
    }

    func testIsTrialActiveZeroStartTsIsFalse() {
        // startTs == 0 means trial was never recorded.
        let now = Date(timeIntervalSince1970: trialStartTs)
        XCTAssertFalse(TrialClock.isTrialActive(startTs: 0, now: now))
    }

    func testIsTrialActiveRefusesClockRewind() {
        // Clock-rewind attack: `now` reads earlier than the recorded start.
        // The legacy implementation returned true (negative elapsed < duration),
        // effectively extending the trial. The new implementation rejects this.
        let now = Date(timeIntervalSince1970: trialStartTs - 1)
        XCTAssertFalse(TrialClock.isTrialActive(startTs: trialStartTs, now: now))
    }

    // MARK: - daysRemaining

    func testDaysRemainingAtStartEqualsWholeWindow() {
        let now = Date(timeIntervalSince1970: trialStartTs)
        // 7 days, ceiling-rounded.
        XCTAssertEqual(TrialClock.daysRemaining(startTs: trialStartTs, now: now), 7)
    }

    func testDaysRemainingAfterOneDayDecrements() {
        let now = Date(timeIntervalSince1970: trialStartTs + 86_400)
        // 6 full days left.
        XCTAssertEqual(TrialClock.daysRemaining(startTs: trialStartTs, now: now), 6)
    }

    func testDaysRemainingCeilsPartialDay() {
        // 5 days + 1 hour elapsed → 2 days minus 1 hour remaining → ceils to 2.
        let now = Date(timeIntervalSince1970: trialStartTs + 5 * 86_400 + 3_600)
        XCTAssertEqual(TrialClock.daysRemaining(startTs: trialStartTs, now: now), 2)
    }

    func testDaysRemainingAfterExpiryIsZero() {
        let now = Date(timeIntervalSince1970: trialStartTs + trialDuration + 1)
        XCTAssertEqual(TrialClock.daysRemaining(startTs: trialStartTs, now: now), 0)
    }

    func testDaysRemainingOnClockRewindIsZero() {
        // isTrialActive returns false on rewind, so daysRemaining cascades to 0.
        let now = Date(timeIntervalSince1970: trialStartTs - 10_000)
        XCTAssertEqual(TrialClock.daysRemaining(startTs: trialStartTs, now: now), 0)
    }

    // MARK: - hasTrialExpired

    func testHasTrialExpiredBeforeWindowIsFalse() {
        let now = Date(timeIntervalSince1970: trialStartTs + 86_400)
        XCTAssertFalse(TrialClock.hasTrialExpired(startTs: trialStartTs, now: now))
    }

    func testHasTrialExpiredAtBoundaryIsTrue() {
        let now = Date(timeIntervalSince1970: trialStartTs + trialDuration)
        XCTAssertTrue(TrialClock.hasTrialExpired(startTs: trialStartTs, now: now))
    }

    func testHasTrialExpiredOnClockRewindIsFalse() {
        // Signed compare — a rewound clock shouldn't spuriously expire an
        // otherwise-active trial. Different semantics from isTrialActive.
        let now = Date(timeIntervalSince1970: trialStartTs - 86_400)
        XCTAssertFalse(TrialClock.hasTrialExpired(startTs: trialStartTs, now: now))
    }

    func testHasTrialExpiredZeroStartTsIsFalse() {
        // No trial ever started.
        XCTAssertFalse(TrialClock.hasTrialExpired(startTs: 0))
    }

    // MARK: - Defensive corner cases

    func testFutureStartTsIsNotActive() {
        // Both the device clock and the recorded startTs are tampered into
        // the future. Elapsed reads negative; isTrialActive must refuse.
        let futureStart = Date().addingTimeInterval(86_400 * 365).timeIntervalSince1970
        let now = Date()
        XCTAssertFalse(TrialClock.isTrialActive(startTs: futureStart, now: now))
        XCTAssertEqual(TrialClock.daysRemaining(startTs: futureStart, now: now), 0)
    }
}
