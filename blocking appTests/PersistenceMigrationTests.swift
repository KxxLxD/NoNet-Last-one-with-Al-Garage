import XCTest
@testable import blocking_app

final class PersistenceMigrationTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "PersistenceMigrationTests.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)!
        // Clean slate
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    // Note: PersistenceMigration uses UserDefaults.standard directly so we can't fully
    // isolate it. These tests verify the stores' clear() semantics on real keys.

    func testBreaksStoreSaveLoadClear() {
        let id = UUID()
        BreaksStore.save(for: id, count: 3, durationMinutes: 10)
        let loaded = BreaksStore.load(for: id)
        XCTAssertEqual(loaded?.count, 3)
        XCTAssertEqual(loaded?.duration, 10)

        BreaksStore.clear(for: id)
        let afterClear = BreaksStore.load(for: id)
        XCTAssertNil(afterClear, "Clear must remove all break keys")
    }

    func testManualStateStoreToggleSetsActiveAndStartTs() {
        let id = UUID()
        XCTAssertFalse(ManualStateStore.isActive(for: id))

        ManualStateStore.toggle(for: id)
        XCTAssertTrue(ManualStateStore.isActive(for: id))
        XCTAssertGreaterThan(ManualStateStore.startTs(for: id), 0)

        ManualStateStore.toggle(for: id)
        XCTAssertFalse(ManualStateStore.isActive(for: id))

        ManualStateStore.clear(for: id)
        XCTAssertFalse(ManualStateStore.isActive(for: id))
    }

    func testBreaksStoreReturnsNilWhenAbsent() {
        let id = UUID()
        XCTAssertNil(BreaksStore.load(for: id))
    }
}
