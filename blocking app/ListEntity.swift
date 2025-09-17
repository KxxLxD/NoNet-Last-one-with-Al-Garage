import Foundation
import CoreData

@objc(ListEntity)
public class ListEntity: NSManagedObject {}

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