//
//  PendingBreakAttemptQueueTests.swift
//  blocking appTests
//
//  Exercises the offline-resilience queue. Tests cover the enqueue/load
//  round-trip, the 50-entry cap (oldest dropped on overflow), individual
//  removal during flush, the .pending status preservation added in v1.4.0
//  (without it, queued approval requests would replay as .logOnly and the
//  partner would never see the approve/deny prompt), and the legacy
//  backward-compat path (records without statusRaw default to .logOnly).
//

import XCTest
@testable import blocking_app

final class PendingBreakAttemptQueueTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PendingBreakAttemptQueue.clear()
    }

    override func tearDown() {
        PendingBreakAttemptQueue.clear()
        super.tearDown()
    }

    func testEnqueueLoadRoundtrip() {
        let attempt = makeAttempt(typeRaw: "delete", reason: "Need to delete")
        PendingBreakAttemptQueue.enqueue(attempt)
        let loaded = PendingBreakAttemptQueue.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, attempt.id)
        XCTAssertEqual(loaded.first?.typeRaw, "delete")
        XCTAssertEqual(loaded.first?.reason, "Need to delete")
    }

    func testEnqueuePreservesStatusRaw() {
        // The status field is what distinguishes "approval request awaiting
        // partner" from "log-only break attempt". Losing it on replay would
        // make every queued .pending record arrive as .logOnly — the partner
        // would never see the approve/deny prompt.
        let attempt = makeAttempt(statusRaw: RequestStatus.pending.rawValue)
        PendingBreakAttemptQueue.enqueue(attempt)
        let loaded = PendingBreakAttemptQueue.load()
        XCTAssertEqual(loaded.first?.statusRaw, RequestStatus.pending.rawValue)
        XCTAssertEqual(loaded.first?.status, .pending)
    }

    func testLegacyRecordWithNilStatusDefaultsToLogOnly() {
        let attempt = makeAttempt(statusRaw: nil)
        PendingBreakAttemptQueue.enqueue(attempt)
        let loaded = PendingBreakAttemptQueue.load()
        XCTAssertNil(loaded.first?.statusRaw)
        // Computed property derives .logOnly when the raw value is nil so
        // pre-v1.4.0 queue entries replay as the legacy fire-and-forget
        // semantic, not as accidental approval requests.
        XCTAssertEqual(loaded.first?.status, .logOnly)
    }

    func testRemoveSingleEntry() {
        let a = makeAttempt(typeRaw: "delete")
        let b = makeAttempt(typeRaw: "disable")
        PendingBreakAttemptQueue.enqueue(a)
        PendingBreakAttemptQueue.enqueue(b)
        PendingBreakAttemptQueue.remove(id: a.id)
        let loaded = PendingBreakAttemptQueue.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, b.id)
    }

    func testQueueCapDropsOldestOnOverflow() {
        // The hardcoded cap is 50; a user offline for months shouldn't grow
        // UserDefaults unboundedly. Insert 55, expect the FIRST 5 to be
        // dropped and the LAST 50 kept — `Array(current.suffix(50))` is the
        // implementation. A bad implementation that kept the first 50 and
        // dropped the last 5 would lose the *most recent* break attempts,
        // which is exactly the wrong direction.
        var insertedIDs: [UUID] = []
        for _ in 0..<55 {
            let attempt = makeAttempt(typeRaw: "delete")
            insertedIDs.append(attempt.id)
            PendingBreakAttemptQueue.enqueue(attempt)
        }
        let loaded = PendingBreakAttemptQueue.load()
        XCTAssertEqual(loaded.count, 50)
        // The first 5 (indices 0…4) must all be absent. Asserting only that
        // index 0 is gone would let a regression slip if the cap dropped a
        // random subset.
        let droppedIDs = Set(insertedIDs.prefix(5))
        for dropped in droppedIDs {
            XCTAssertFalse(loaded.contains(where: { $0.id == dropped }),
                           "Entry inserted at position \(insertedIDs.firstIndex(of: dropped) ?? -1) should be evicted")
        }
        // The last 50 (indices 5…54) must all be present, and in insertion order.
        let expectedKeptIDs = Array(insertedIDs.suffix(50))
        XCTAssertEqual(loaded.map { $0.id }, expectedKeptIDs,
                       "Surviving entries must be the newest 50, in insertion order")
    }

    func testEncodingPreservesAllFields() {
        // Round-trip exercises every optional + required field on a single
        // record, so a stray Codable customization that misses a field
        // (e.g. forgot to encode `reason`) gets caught here even if the
        // happy-path tests never set that field.
        let attempt = PendingBreakAttempt(
            id: UUID(),
            partnershipID: "partner-\(UUID().uuidString)",
            listID: UUID(),
            listName: "Full-fields list",
            attemptedAt: Date(timeIntervalSince1970: 1_700_000_000),
            typeRaw: "delete",
            reachedThrough: "ui-test-path",
            statusRaw: RequestStatus.pending.rawValue,
            reason: "Detailed explanation that must survive the round-trip"
        )
        PendingBreakAttemptQueue.enqueue(attempt)
        let loaded = try? XCTUnwrap(PendingBreakAttemptQueue.load().first)
        XCTAssertEqual(loaded?.id, attempt.id)
        XCTAssertEqual(loaded?.partnershipID, attempt.partnershipID)
        XCTAssertEqual(loaded?.listID, attempt.listID)
        XCTAssertEqual(loaded?.listName, attempt.listName)
        XCTAssertEqual(loaded?.attemptedAt.timeIntervalSince1970,
                       attempt.attemptedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(loaded?.typeRaw, "delete")
        XCTAssertEqual(loaded?.reachedThrough, "ui-test-path")
        XCTAssertEqual(loaded?.statusRaw, RequestStatus.pending.rawValue)
        XCTAssertEqual(loaded?.reason, attempt.reason)
    }

    func testClearEmptiesQueue() {
        PendingBreakAttemptQueue.enqueue(makeAttempt(typeRaw: "delete"))
        PendingBreakAttemptQueue.enqueue(makeAttempt(typeRaw: "delete"))
        XCTAssertEqual(PendingBreakAttemptQueue.depth, 2)
        PendingBreakAttemptQueue.clear()
        XCTAssertEqual(PendingBreakAttemptQueue.depth, 0)
    }

    func testDepthMatchesLoadCount() {
        for _ in 0..<3 {
            PendingBreakAttemptQueue.enqueue(makeAttempt(typeRaw: "delete"))
        }
        XCTAssertEqual(PendingBreakAttemptQueue.depth, 3)
        XCTAssertEqual(PendingBreakAttemptQueue.load().count, 3)
    }

    // MARK: - Helpers

    private func makeAttempt(
        typeRaw: String = "delete",
        statusRaw: String? = nil,
        reason: String? = nil
    ) -> PendingBreakAttempt {
        PendingBreakAttempt(
            id: UUID(),
            partnershipID: UUID().uuidString,
            listID: UUID(),
            listName: "Test list",
            attemptedAt: Date(),
            typeRaw: typeRaw,
            reachedThrough: "test",
            statusRaw: statusRaw,
            reason: reason
        )
    }
}
