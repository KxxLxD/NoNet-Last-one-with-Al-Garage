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
        list.blockType = "scheduled"  // scheduled+hard is NOT a forever-style lock
        list.durationSeconds = 0
        list.createdAt = Date()
        list.updatedAt = Date()

        XCTAssertFalse(BlockingEngine.shared.isHardLocked(list: list))

        context.delete(list)
        try? context.save()
    }

    // MARK: - v1.1.0 additions: Forever and Time-Limit

    @MainActor
    func testIsHardLockedReturnsTrueForForeverHardMode() {
        // Forever + Hard = permanent lock with no natural end date.
        let list = ListEntity(context: context)
        list.id = UUID()
        list.name = "test-forever-hard"
        list.protection = "hard"
        list.blockType = "forever"
        list.durationSeconds = 0
        // Even a list created in the distant past must remain hard-locked.
        list.createdAt = Date().addingTimeInterval(-86400 * 365)
        list.updatedAt = Date()

        XCTAssertTrue(BlockingEngine.shared.isHardLocked(list: list),
                      "Forever + Hard must lock indefinitely regardless of createdAt")

        context.delete(list)
        try? context.save()
    }

    @MainActor
    func testIsHardLockedReturnsFalseForForeverNoProtection() {
        // Forever without Hard Mode is editable — the user can delete the list.
        let list = ListEntity(context: context)
        list.id = UUID()
        list.name = "test-forever-soft"
        list.protection = "noProtection"
        list.blockType = "forever"
        list.durationSeconds = 0
        list.createdAt = Date()
        list.updatedAt = Date()

        XCTAssertFalse(BlockingEngine.shared.isHardLocked(list: list))

        context.delete(list)
        try? context.save()
    }

    @MainActor
    func testIsHardLockedReturnsTrueForTimeLimitHardMode() {
        // TimeLimit + Hard = recurring daily quota with no natural end — treat like Forever.
        let list = ListEntity(context: context)
        list.id = UUID()
        list.name = "test-timelimit-hard"
        list.protection = "hard"
        list.blockType = "timeLimit"
        list.durationSeconds = Int64(60 * 60) // 60 min daily quota encoded
        list.createdAt = Date().addingTimeInterval(-86400 * 30)
        list.updatedAt = Date()

        XCTAssertTrue(BlockingEngine.shared.isHardLocked(list: list),
                      "TimeLimit + Hard must lock indefinitely")

        context.delete(list)
        try? context.save()
    }

    @MainActor
    func testIsHardLockedReturnsFalseForTimeLimitNoProtection() {
        let list = ListEntity(context: context)
        list.id = UUID()
        list.name = "test-timelimit-soft"
        list.protection = "noProtection"
        list.blockType = "timeLimit"
        list.durationSeconds = Int64(60 * 60)
        list.createdAt = Date()
        list.updatedAt = Date()

        XCTAssertFalse(BlockingEngine.shared.isHardLocked(list: list))

        context.delete(list)
        try? context.save()
    }
}
