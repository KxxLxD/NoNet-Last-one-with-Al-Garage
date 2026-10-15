import XCTest
import CloudKit
@testable import blocking_app

/// Tests for the CloudKit Partner store DTOs and bridging logic that don't
/// require a live iCloud account. End-to-end share flow (CKShare + accept on a
/// second device) lives in `TODO_FOR_KHALID.md` as manual two-device QA.
final class CloudKitPartnerStoreTests: XCTestCase {

    // MARK: - Partnership round-trips

    func testPartnershipFromValidRecord() {
        let record = CKRecord(recordType: PartnerRecordTypes.partnership,
                              recordID: CKRecord.ID(recordName: "abc123"))
        record["ownerUserID"] = "user-1" as CKRecordValue
        record["ownerDisplayName"] = "Khalid" as CKRecordValue
        record["status"] = PartnershipStatus.accepted.rawValue as CKRecordValue
        record["createdAt"] = Date(timeIntervalSince1970: 1_700_000_000) as CKRecordValue
        record["acceptedAt"] = Date(timeIntervalSince1970: 1_700_010_000) as CKRecordValue
        record["partnerUserID"] = "user-2" as CKRecordValue
        record["partnerDisplayName"] = "Ali" as CKRecordValue
        let listID = UUID()
        record["associatedListIDs"] = [listID.uuidString] as CKRecordValue

        let parsed = Partnership(from: record)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.id, "abc123")
        XCTAssertEqual(parsed?.ownerUserID, "user-1")
        XCTAssertEqual(parsed?.ownerDisplayName, "Khalid")
        XCTAssertEqual(parsed?.partnerUserID, "user-2")
        XCTAssertEqual(parsed?.partnerDisplayName, "Ali")
        XCTAssertEqual(parsed?.status, .accepted)
        XCTAssertEqual(parsed?.associatedListIDs, [listID])
        XCTAssertNotNil(parsed?.acceptedAt)
    }

    func testPartnershipFromPendingRecordHasNoPartnerYet() {
        // Inviter-side state: record exists but the invitee hasn't accepted yet.
        let record = CKRecord(recordType: PartnerRecordTypes.partnership,
                              recordID: CKRecord.ID(recordName: "pending-1"))
        record["ownerUserID"] = "user-1" as CKRecordValue
        record["ownerDisplayName"] = "Khalid" as CKRecordValue
        record["status"] = PartnershipStatus.pending.rawValue as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["associatedListIDs"] = [UUID().uuidString] as CKRecordValue

        let parsed = Partnership(from: record)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.status, .pending)
        XCTAssertNil(parsed?.partnerUserID, "Pending records have no partner yet")
        XCTAssertNil(parsed?.acceptedAt)
    }

    func testPartnershipFromMalformedRecordFailsGracefully() {
        // Missing the required `status` field — init should return nil rather than crash.
        let record = CKRecord(recordType: PartnerRecordTypes.partnership,
                              recordID: CKRecord.ID(recordName: "broken"))
        record["ownerUserID"] = "user-1" as CKRecordValue
        record["ownerDisplayName"] = "Khalid" as CKRecordValue
        // intentionally no `status`, `createdAt`
        XCTAssertNil(Partnership(from: record))
    }

    func testPartnershipFromUnknownStatusFailsGracefully() {
        let record = CKRecord(recordType: PartnerRecordTypes.partnership,
                              recordID: CKRecord.ID(recordName: "weird"))
        record["ownerUserID"] = "user-1" as CKRecordValue
        record["ownerDisplayName"] = "Khalid" as CKRecordValue
        record["status"] = "alien-status" as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        // An unknown status string must round-trip to nil so a server-side rename
        // doesn't trigger a runtime crash on clients with stale enum cases.
        XCTAssertNil(Partnership(from: record))
    }

    func testPartnershipDropsInvalidListIDStrings() {
        let record = CKRecord(recordType: PartnerRecordTypes.partnership,
                              recordID: CKRecord.ID(recordName: "mixed-ids"))
        record["ownerUserID"] = "user-1" as CKRecordValue
        record["ownerDisplayName"] = "Khalid" as CKRecordValue
        record["status"] = PartnershipStatus.accepted.rawValue as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        let validID = UUID()
        record["associatedListIDs"] = [validID.uuidString, "not-a-uuid", ""] as CKRecordValue

        let parsed = Partnership(from: record)
        XCTAssertEqual(parsed?.associatedListIDs, [validID],
                       "Bad UUID strings must be silently filtered, leaving valid ones")
    }

    // MARK: - BreakAttempt round-trips

    func testBreakAttemptFromValidRecord() {
        let partnershipRecordID = CKRecord.ID(recordName: "partnership-X")
        let record = CKRecord(recordType: PartnerRecordTypes.breakAttempt,
                              recordID: CKRecord.ID(recordName: "attempt-1"))
        record["partnershipID"] = CKRecord.Reference(recordID: partnershipRecordID, action: .none)
        let listID = UUID()
        record["listID"] = listID.uuidString as CKRecordValue
        record["listName"] = "Focus Time" as CKRecordValue
        record["attemptedAt"] = Date(timeIntervalSince1970: 1_700_020_000) as CKRecordValue
        record["attemptType"] = BreakAttemptType.delete.rawValue as CKRecordValue
        record["reachedThrough"] = "home_delete_button" as CKRecordValue

        let parsed = BreakAttempt(from: record)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.id, "attempt-1")
        XCTAssertEqual(parsed?.partnershipID, "partnership-X")
        XCTAssertEqual(parsed?.listID, listID)
        XCTAssertEqual(parsed?.listName, "Focus Time")
        XCTAssertEqual(parsed?.type, .delete)
        XCTAssertEqual(parsed?.reachedThrough, "home_delete_button")
    }

    func testBreakAttemptReachedThroughIsOptional() {
        let record = CKRecord(recordType: PartnerRecordTypes.breakAttempt,
                              recordID: CKRecord.ID(recordName: "attempt-2"))
        record["partnershipID"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: "p"), action: .none
        )
        record["listID"] = UUID().uuidString as CKRecordValue
        record["listName"] = "x" as CKRecordValue
        record["attemptedAt"] = Date() as CKRecordValue
        record["attemptType"] = BreakAttemptType.disable.rawValue as CKRecordValue
        // No reachedThrough — should parse fine.
        let parsed = BreakAttempt(from: record)
        XCTAssertNotNil(parsed)
        XCTAssertNil(parsed?.reachedThrough)
    }

    func testBreakAttemptFromMalformedRecordFailsGracefully() {
        let record = CKRecord(recordType: PartnerRecordTypes.breakAttempt,
                              recordID: CKRecord.ID(recordName: "broken"))
        // Missing partnershipID and listID entirely
        record["attemptType"] = BreakAttemptType.delete.rawValue as CKRecordValue
        XCTAssertNil(BreakAttempt(from: record))
    }

    // MARK: - Status / record-type constants

    func testRecordTypeNamesAreStable() {
        // These strings are part of the on-server schema. Renaming them silently
        // would break every existing user's data — the test pins them.
        XCTAssertEqual(PartnerRecordTypes.partnership, "Partnership")
        XCTAssertEqual(PartnerRecordTypes.breakAttempt, "BreakAttempt")
        XCTAssertEqual(PartnerRecordTypes.partnerProfile, "PartnerProfile")
    }

    func testPartnershipStatusRawValuesAreStable() {
        // Pinned because they're persisted in CloudKit. Renaming = data migration.
        XCTAssertEqual(PartnershipStatus.pending.rawValue, "pending")
        XCTAssertEqual(PartnershipStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(PartnershipStatus.rejected.rawValue, "rejected")
        XCTAssertEqual(PartnershipStatus.revoked.rawValue, "revoked")
    }

    func testBreakAttemptTypeRawValuesAreStable() {
        XCTAssertEqual(BreakAttemptType.disable.rawValue, "disable")
        XCTAssertEqual(BreakAttemptType.delete.rawValue, "delete")
        XCTAssertEqual(BreakAttemptType.modify.rawValue, "modify")
        // Note: uninstallAttempt deliberately uses snake_case for backwards
        // compatibility with any pre-existing records.
        XCTAssertEqual(BreakAttemptType.uninstallAttempt.rawValue, "uninstall_attempt")
    }
}
