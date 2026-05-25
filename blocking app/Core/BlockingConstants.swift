//
//  BlockingConstants.swift
//  blocking app
//
//  Single source of truth for magic numbers around list creation, breaks, and timing.
//

import Foundation

enum BlockingConstants {
    /// Allowed break-duration choices, in minutes.
    static let breakDurationOptions: [Int] = [5, 10, 15]

    /// Allowed break-count choices.
    static let breakCountOptions: [Int] = [0, 1, 2, 3, 4, 5]

    /// Minimum blocking duration in seconds (5 minutes).
    static let minBlockSeconds: Int = 300

    /// Wheel-picker stride for minutes selection.
    static let minutePickerStride: Int = 5

    /// Free-tier maximum number of lists.
    static let freeTierListLimit: Int = 3

    /// Free-tier maximum number of Hard-Mode lists. Combined with Forever block
    /// type, an unbounded count would collapse the value of upgrading.
    static let freeTierHardLimit: Int = 1

    /// Free trial duration (7 days, in seconds).
    static let trialDurationSeconds: TimeInterval = 7 * 24 * 3600

    /// Allowed daily Time-Limit choices, in minutes. After the user has used the
    /// blocked apps/sites for this many minutes in a day, shields apply until midnight.
    static let timeLimitOptions: [Int] = [15, 30, 60, 90, 120]

    /// Delay between requesting an emergency unlock for a Hard + Forever list
    /// and the lock actually being released. Long enough to break the impulse
    /// (the lock exists *for* that impulse) but bounded so the user is never
    /// permanently held. Matches the patterns Apple Review has accepted in
    /// Cold Turkey and Opal Hard Mode.
    static let emergencyUnlockDelaySeconds: TimeInterval = 72 * 60 * 60
}
