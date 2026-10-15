import Foundation
import CoreData

@objc(ListEntity)
public class ListEntity: NSManagedObject {}

// NSManagedObject already conforms to Identifiable via NSObject's
// ObjectIdentifier — we don't redeclare it. The `id: UUID` declared in
// the extension below is our domain identifier (used in storage keys,
// CloudKit references, etc.) but coexists with the protocol's default.

extension ListEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ListEntity> {
        return NSFetchRequest<ListEntity>(entityName: "ListEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var protection: String // hard | noProtection
    @NSManaged public var blockType: String  // now | scheduled
    @NSManaged public var durationSeconds: Int64
    @NSManaged public var scheduleSlots: Data?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    /// Who guards this list against deletion/disable/modify when Hard Mode
    /// is active. "nonet" = NoNet itself (200-char reason or 7-day wait).
    /// "partner" = a human Recovery Partner approves/denies requests.
    /// Defaults to "nonet" — see PersistenceMigration.runIfNeeded.
    @NSManaged public var gatekeeperType: String

    @NSManaged public var items: Set<BlockItemEntity>?
} 

@objc(BlockItemEntity)
public class BlockItemEntity: NSManagedObject {}

extension BlockItemEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BlockItemEntity> {
        return NSFetchRequest<BlockItemEntity>(entityName: "BlockItemEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var kind: String // website | app | category
    @NSManaged public var value: String
    @NSManaged public var displayName: String?

    @NSManaged public var list: ListEntity?
} 