import XCTest
import CoreData
@testable import blocking_app

/// Tests for BlockingEngine that don't require Screen Time authorization.
/// Activation/shield tests require a real device with Family Controls granted —
/// those are documented in `docs/RETRO_2026-05-22.md` as manual testing scope.
final class BlockingEngineTests: XCTestCase {
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = CoreDataStack.shared.viewContext
    }

    @MainActor
    func testIsHardLockedReturnsTrueForActiveHardModeNow() {
        let list = ListEntity(context: context)
        list.id = UUID()
        list.name = "test-hard-active"
        list.protection = "hard"
        list.blockType = "now"
        list.durationSeconds = 3600 // 1 hour
        list.createdAt = Date() // just started
        list.updatedAt = Date()

        XCTAssertTrue(BlockingEngine.shared.isHardLocked(list: list))

        // Cleanup
        context.delete(list)
        try? context.save()
    }

    @MainActor
    func testIsHardLockedReturnsFalseForExpiredHardMode() {
        let list = ListEntity(context: context)
        list.id = UUID()
        list.name = "test-hard-expired"
        list.protection = "hard"
        list.blockType = "now"
        list.durationSeconds = 60
        list.createdAt = Date().addingTimeInterval(-3600) // started an hour ago, lasted 60s
        list.updatedAt = Date()

        XCTAssertFalse(BlockingEngine.shared.isHardLocked(list: list))

        context.delete(list)
        try? context.save()
    }

    @MainActor
    func testIsHardLockedReturnsFalseForNonHardMode() {
        let list = ListEntity(context: context)
        list.id = UUID()
        list.name = "test-soft"
        list.protection = "noProtection"
        list.blockType = "now"
        list.durationSeconds = 3600
        list.createdAt = Date()
        list.updatedAt = Date()

        XCTAssertFalse(BlockingEngine.shared.isHardLocked(list: list))

        context.delete(list)
        try? context.save()
    }

    @MainActor
    func testIsHardLockedReturnsFalseForScheduledList() {
        let list = ListEntity(context: context)
        list.id = UUID()
        list.name = "test-scheduled-hard"
        list.protection = "hard"
        list.blockType = "scheduled"  // only "now" + hard is true hard-lock
        list.durationSeconds = 0
        list.createdAt = Date()
        list.updatedAt = Date()

        XCTAssertFalse(BlockingEngine.shared.isHardLocked(list: list))

        context.delete(list)
        try? context.save()
    }
}
