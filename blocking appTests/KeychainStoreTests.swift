import XCTest
@testable import blocking_app

final class KeychainStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Ensure clean slate for each test
        _ = KeychainStore.remove(.appleUserID)
    }

    override func tearDown() {
        _ = KeychainStore.remove(.appleUserID)
        super.tearDown()
    }

    func testSetAndGetValue() {
        let value = "test-apple-user-id-001"
        XCTAssertTrue(KeychainStore.set(value, for: .appleUserID))
        XCTAssertEqual(KeychainStore.get(.appleUserID), value)
    }

    func testGetReturnsNilWhenAbsent() {
        XCTAssertNil(KeychainStore.get(.appleUserID))
    }

    func testSetOverwritesExisting() {
        XCTAssertTrue(KeychainStore.set("first", for: .appleUserID))
        XCTAssertTrue(KeychainStore.set("second", for: .appleUserID))
        XCTAssertEqual(KeychainStore.get(.appleUserID), "second")
    }

    func testRemove() {
        XCTAssertTrue(KeychainStore.set("temp", for: .appleUserID))
        XCTAssertTrue(KeychainStore.remove(.appleUserID))
        XCTAssertNil(KeychainStore.get(.appleUserID))
    }

    func testRemoveAbsentSucceeds() {
        // Removing a non-existent item should still report success per Keychain semantics
        XCTAssertTrue(KeychainStore.remove(.appleUserID))
    }
}
