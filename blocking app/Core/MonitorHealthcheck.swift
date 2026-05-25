//
//  MonitorHealthcheck.swift
//  blocking app
//
//  Detects whether the BlockingMonitor extension is actually running and
//  surfaces that to the user when it isn't.
//
//  Background: BlockingEngine.scheduleMonitoring and scheduleTimeLimit register
//  schedules with DeviceActivityCenter, but the shields don't apply unless the
//  DeviceActivityMonitor extension target is correctly bound, signed with the
//  right entitlements, and granted the shared App Group. Any of those failing
//  results in silently inactive Scheduled/Time-Limit blocks — exactly the kind
//  of failure that turns into 1-star App Store reviews.
//
//  Mechanism: the extension writes a heartbeat timestamp to the shared App
//  Group whenever DeviceActivity fires it. The main app reads that timestamp
//  on appear, and if the user has Scheduled or Time-Limit lists that should
//  have triggered the extension by now but the heartbeat is missing, we show
//  a banner directing them to support.
//
//  The heartbeat key is referenced by literal string from BlockingMonitor.swift
//  (which lives in a separate extension target and can't import this file).
//  Keep the string in sync if it ever changes.
//

import Foundation

enum MonitorHealthcheck {
    /// Shared App Group key written by BlockingMonitor (intervalDidStart /
    /// intervalDidEnd / eventDidReachThreshold). Read here.
    /// Must match the literal used by BlockingMonitor.swift.
    static let heartbeatKey = "v1:monitor:heartbeat"

    /// Grace period after the oldest scheduled-or-time-limit list was created
    /// before we expect to have seen at least one extension callback. 24 hours
    /// is generous enough for any user's first scheduled window to open and
    /// for any Time-Limit schedule to roll past midnight.
    static let heartbeatExpectedWithin: TimeInterval = 24 * 60 * 60

    /// Most recent heartbeat written by the extension, or nil if it has never fired.
    static var lastHeartbeat: Date? {
        guard let defaults = sharedDefaultsOptional else { return nil }
        let ts = defaults.double(forKey: heartbeatKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    /// True when the user should be warned that the extension isn't firing.
    ///
    /// Conditions:
    ///   1. The user has at least one Scheduled or Time-Limit list whose
    ///      creation predates the grace window, AND
    ///   2. Either the App Group is missing (the extension cannot share data
    ///      with the app even if it does run), OR no heartbeat has been
    ///      recorded since the oldest such list was created.
    static func shouldShowBanner(
        oldestScheduledOrLimit: Date?,
        now: Date = Date()
    ) -> Bool {
        guard let oldest = oldestScheduledOrLimit else { return false }
        guard now.timeIntervalSince(oldest) > heartbeatExpectedWithin else { return false }
        if !isAppGroupActive { return true }
        guard let last = lastHeartbeat else { return true }
        return last < oldest
    }
}
