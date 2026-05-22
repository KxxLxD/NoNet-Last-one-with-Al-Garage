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
}
