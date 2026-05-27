//
//  EmergencyUnlockStoreTests.swift
//  blocking appTests
//
//  Exercises the @MainActor ObservableObject EmergencyUnlockStore. Covers the
//  request → wait → grant lifecycle, the cancel path, persistence semantics
//  (state mirrors UserDefaults so a relaunch picks up in-flight requests),
//  and the per-id isolation (one list's request doesn't affect another's).
//

import XCTest
@testable import blocking_app

@MainActor
final class EmergencyUnlockStoreTests: XCTestCase {
    private let listA = UUID()
    private let listB = UUID()
    private var store: EmergencyUnlockStore!

    override func setUp() async throws {
        try await super.setUp()
        // Tests use the shared singleton — the store reads UserDefaults at
        // init, so we wipe any leftovers from a previous run before each test.
        let d = UserDefaults.standard
        for k in d.dictionaryRepresentation().keys where k.hasPrefix("v1:emergencyUnlock:") {
            d.removeObject(forKey: k)
        }
        store = EmergencyUnlockStore.shared
        // Force the @Published dictionary to a clean slate too — the shared
        // singleton survives between tests in the same run.
        for id in [listA, listB] { store.clear(for: id) }
    }

    func testRequestUnlockRecordsTimestamp() {
        let now = Date()
        store.requestUnlock(for: listA, now: now)
        XCTAssertEqual(store.requestedAt(for: listA), now)
    }

    func testIsGrantedFalseBeforeDelayElapsed() {
        let now = Date()
        store.requestUnlock(for: listA, now: now)
        // 1 second later — nowhere near the 7-day delay.
        XCTAssertFalse(store.isGranted(for: listA, now: now.addingTimeInterval(1)))
    }

    func testIsGrantedTrueAfterDelayElapsed() {
        let now = Date()
        store.requestUnlock(for: listA, now: now)
        let after = now.addingTimeInterval(BlockingConstants.emergencyUnlockDelaySeconds + 1)
        XCTAssertTrue(store.isGranted(for: listA, now: after))
    }

    func testRemainingSecondsCountsDown() {
        let now = Date()
        store.requestUnlock(for: listA, now: now)
        let halfWay = now.addingTimeInterval(BlockingConstants.emergencyUnlockDelaySeconds / 2)
        let remaining = store.remainingSeconds(for: listA, now: halfWay)
        // Half the delay, give or take a rounding hair.
        XCTAssertEqual(remaining, BlockingConstants.emergencyUnlockDelaySeconds / 2, accuracy: 1)
    }

    func testRemainingSecondsIsZeroAfterGrant() {
        let now = Date()
        store.requestUnlock(for: listA, now: now)
        let after = now.addingTimeInterval(BlockingConstants.emergencyUnlockDelaySeconds + 100)
        XCTAssertEqual(store.remainingSeconds(for: listA, now: after), 0)
    }

    func testClearRemovesRequest() {
        store.requestUnlock(for: listA)
        XCTAssertNotNil(store.requestedAt(for: listA))
        store.clear(for: listA)
        XCTAssertNil(store.requestedAt(for: listA))
        XCTAssertFalse(store.isGranted(for: listA))
    }

    func testPerListIsolation() {
        // Request for A doesn't leak into B. Each list's countdown is
        // independent — the per-id dictionary is the contract.
        store.requestUnlock(for: listA)
        XCTAssertNotNil(store.requestedAt(for: listA))
        XCTAssertNil(store.requestedAt(for: listB))
    }

    func testStateMirrorsUserDefaults() {
        // The @Published dictionary should reflect what's persisted, so a
        // process restart (which reloads from UserDefaults in init) sees the
        // same state observers were seeing pre-restart.
        let now = Date()
        store.requestUnlock(for: listA, now: now)
        let persistedRaw = UserDefaults.standard.double(forKey: "v1:emergencyUnlock:requestedAt:\(listA.uuidString)")
        XCTAssertEqual(persistedRaw, now.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(store.requestedAtByID[listA], now)
    }
}
