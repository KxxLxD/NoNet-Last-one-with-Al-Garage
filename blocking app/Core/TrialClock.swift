//
//  TrialClock.swift
//  blocking app
//
//  Centralised free-trial elapsed-time math. Previously the same
//  isTrialActive + daysRemaining shapes were inlined in UpgradeView,
//  HomeView, and ContentView with subtle differences (signed vs.
//  unsigned subtraction, different fall-through behavior). Two of them
//  were also vulnerable to the trivial clock-rewind attack — moving the
//  device clock backwards extended the trial window.
//
//  Defense-in-depth note: this helper only powers the "trial countdown"
//  UI affordance. StoreKit's `Transaction.currentEntitlements` is the
//  authoritative Premium state, and `StoreManager.refreshEntitlements`
//  re-verifies it on every launch. A clock-savvy user can't unlock paid
//  features by rewinding — they can only confuse the trial banner.
//

import Foundation

enum TrialClock {
    /// True while the 7-day free trial window is still open. Treats a
    /// negative elapsed reading (clock moved backwards) as expired so a
    /// device-clock rewind doesn't grant extra trial time.
    static func isTrialActive(startTs: Double, now: Date = Date()) -> Bool {
        guard startTs > 0 else { return false }
        let elapsed = now.timeIntervalSince(Date(timeIntervalSince1970: startTs))
        if elapsed < 0 { return false }
        return elapsed < BlockingConstants.trialDurationSeconds
    }

    /// Days remaining in the trial window, rounded up so a partial day
    /// reads as "1 day left" rather than "0". Returns 0 when the trial
    /// is over, never started, or appears to be in the future (rewound
    /// clock).
    static func daysRemaining(startTs: Double, now: Date = Date()) -> Int {
        guard isTrialActive(startTs: startTs, now: now) else { return 0 }
        let elapsed = now.timeIntervalSince(Date(timeIntervalSince1970: startTs))
        let remaining = BlockingConstants.trialDurationSeconds - elapsed
        return max(0, Int(ceil(remaining / BlockingConstants.secondsPerDayInterval)))
    }

    /// True once the trial window has actually elapsed (signed compare,
    /// so a rewound clock does NOT spuriously expire an active trial).
    /// Used by `ContentView.expireTrialIfNeeded` to demote the user
    /// back to free tier with the one-shot expired alert.
    static func hasTrialExpired(startTs: Double, now: Date = Date()) -> Bool {
        guard startTs > 0 else { return false }
        let elapsed = now.timeIntervalSince(Date(timeIntervalSince1970: startTs))
        return elapsed >= BlockingConstants.trialDurationSeconds
    }
}
