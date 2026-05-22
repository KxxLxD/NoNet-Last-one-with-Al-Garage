import XCTest
@testable import blocking_app

final class SchedulePersistenceTests: XCTestCase {
    func testEncodeDecodeRoundtrip() throws {
        let slots = [
            ScheduleSlotV1(id: UUID(), day: 0, fromMinutes: 540, toMinutes: 780),
            ScheduleSlotV1(id: UUID(), day: 5, fromMinutes: 1260, toMinutes: 1380)
        ]
        let data = try XCTUnwrap(SchedulePersistence.encode(slots))
        let decoded = SchedulePersistence.decode(data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].day, 0)
        XCTAssertEqual(decoded[0].fromMinutes, 540)
        XCTAssertEqual(decoded[1].day, 5)
    }

    func testDecodeLegacyArrayFormat() throws {
        // Pre-versioning format: bare JSON array
        let legacySlots = [ScheduleSlotV1(id: UUID(), day: 3, fromMinutes: 0, toMinutes: 60)]
        let legacyData = try JSONEncoder().encode(legacySlots)
        let decoded = SchedulePersistence.decode(legacyData)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].day, 3)
    }

    func testDecodeEmptyDataReturnsEmpty() {
        let decoded = SchedulePersistence.decode(Data())
        XCTAssertEqual(decoded.count, 0)
    }

    func testDecodeCorruptDataReturnsEmpty() {
        let corrupt = "not json".data(using: .utf8)!
        let decoded = SchedulePersistence.decode(corrupt)
        XCTAssertEqual(decoded.count, 0)
    }

    func testEncodeEmptySlotsProducesValidPayload() throws {
        let data = try XCTUnwrap(SchedulePersistence.encode([]))
        let decoded = SchedulePersistence.decode(data)
        XCTAssertEqual(decoded.count, 0)
    }
}
