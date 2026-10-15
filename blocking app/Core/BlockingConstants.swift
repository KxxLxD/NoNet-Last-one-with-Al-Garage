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

    /// Default duration in seconds for lists materialized by `SmartListSeeder`
    /// from onboarding answers. 1 hour — long enough to feel meaningful,
    /// short enough that a confused user isn't locked out for the whole day.
    static let seederDefaultDurationSeconds: Int64 = 3600

    /// Points required to advance one challenge level. Level is computed
    /// as `(totalPoints / challengePointsPerLevel) + 1`, so 200 points = level 2.
    /// Tuned to make the first 3-4 challenges noticeable but level 5+ still
    /// require sustained engagement.
    static let challengePointsPerLevel: Int = 200

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
    ///
    /// Now 7 days (was 72h) — reframed as the user-visible "NoNet is your
    /// gatekeeper" wait path. Surfaced via NoNetGatekeeperSheet rather than
    /// hidden behind a HomeView hold-press, so the user picks it consciously
    /// when creating the list.
    static let emergencyUnlockDelaySeconds: TimeInterval = 7 * 24 * 60 * 60

    /// Minimum character count for the "strong reason" override path in
    /// NoNetGatekeeperSheet. High enough that an impulsive user can't blow
    /// through it, low enough that a genuinely motivated user can.
    static let strongReasonMinCharacters: Int = 200

    // MARK: - Time units (named to kill magic numbers across the app)

    /// Seconds in one minute.
    static let secondsPerMinute: Int = 60
    /// Seconds in one hour.
    static let secondsPerHour: Int = 3600
    /// Seconds in one day.
    static let secondsPerDay: Int = 86_400
    /// Seconds in one day, as `TimeInterval` for date math.
    static let secondsPerDayInterval: TimeInterval = 86_400
}
