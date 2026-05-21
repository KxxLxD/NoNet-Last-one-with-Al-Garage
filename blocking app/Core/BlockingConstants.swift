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

    /// Free trial duration (7 days, in seconds).
    static let trialDurationSeconds: TimeInterval = 7 * 24 * 3600
}
