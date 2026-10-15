import XCTest
@testable import blocking_app

final class BlockingConstantsTests: XCTestCase {
    func testBreakDurationOptionsSorted() {
        let opts = BlockingConstants.breakDurationOptions
        XCTAssertEqual(opts, opts.sorted(), "Break durations must be sorted ascending")
        XCTAssertFalse(opts.isEmpty)
        XCTAssertTrue(opts.allSatisfy { $0 > 0 }, "All durations must be positive")
    }

    func testMinBlockSecondsReasonable() {
        XCTAssertGreaterThanOrEqual(BlockingConstants.minBlockSeconds, 60, "Minimum block ≥ 1 minute")
        XCTAssertLessThanOrEqual(BlockingConstants.minBlockSeconds, 3600, "Minimum block ≤ 1 hour")
    }

    func testMinutePickerStrideDivides60() {
        XCTAssertEqual(60 % BlockingConstants.minutePickerStride, 0,
                       "Stride must divide 60 evenly so minute picker covers full hour")
    }

    func testTrialDurationIs7Days() {
        XCTAssertEqual(BlockingConstants.trialDurationSeconds, 7 * 24 * 3600)
    }

    func testFreeTierListLimitReasonable() {
        XCTAssertGreaterThan(BlockingConstants.freeTierListLimit, 0)
        XCTAssertLessThanOrEqual(BlockingConstants.freeTierListLimit, 10)
    }

    func testBreakCountOptionsIncludesZero() {
        XCTAssertTrue(BlockingConstants.breakCountOptions.contains(0),
                      "Users must be able to choose 0 breaks")
    }

    // MARK: - v1.1.0 additions

    func testTimeLimitOptionsAreSorted() {
        let opts = BlockingConstants.timeLimitOptions
        XCTAssertEqual(opts, opts.sorted(), "Time-limit options must be sorted ascending")
        XCTAssertFalse(opts.isEmpty)
        XCTAssertTrue(opts.allSatisfy { $0 > 0 }, "All limits must be positive minutes")
    }

    func testTimeLimitOptionsCoverReasonableRange() {
        let opts = BlockingConstants.timeLimitOptions
        guard let min = opts.min(), let max = opts.max() else {
            XCTFail("timeLimitOptions must contain at least one value")
            return
        }
        XCTAssertGreaterThanOrEqual(min, 5, "Smallest daily quota should be ≥ 5 minutes")
        XCTAssertLessThanOrEqual(max, 240, "Largest daily quota should be ≤ 4 hours")
    }

    func testFreeTierHardLimitIsExactlyOne() {
        // Premium upgrade hinges on this: free users get exactly one Hard-Mode
        // list. Combined with Forever, more would undermine monetization.
        XCTAssertEqual(BlockingConstants.freeTierHardLimit, 1)
    }

    func testFreeTierHardLimitNeverExceedsListLimit() {
        XCTAssertLessThanOrEqual(BlockingConstants.freeTierHardLimit,
                                 BlockingConstants.freeTierListLimit,
                                 "Free Hard-Mode cap can't exceed the total free list cap")
    }
}
