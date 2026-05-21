//
//  blocking_appApp.swift
//  blocking app
//
//  Created by Khalid Khamid on 12/03/1447 AH.
//

import SwiftUI
import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    private init() {
        // Build model programmatically
        let model = NSManagedObjectModel()

        // ListEntity
        let listEntity = NSEntityDescription()
        listEntity.name = "ListEntity"
        listEntity.managedObjectClassName = String(describing: ListEntity.self)

        let list_id = NSAttributeDescription()
        list_id.name = "id"
        list_id.attributeType = .UUIDAttributeType
        list_id.isOptional = false

        let list_name = NSAttributeDescription()
        list_name.name = "name"
        list_name.attributeType = .stringAttributeType
        list_name.isOptional = false

        let list_protection = NSAttributeDescription()
        list_protection.name = "protection"
        list_protection.attributeType = .stringAttributeType
        list_protection.isOptional = false

        let list_blockType = NSAttributeDescription()
        list_blockType.name = "blockType"
        list_blockType.attributeType = .stringAttributeType
        list_blockType.isOptional = false

        let list_durationSeconds = NSAttributeDescription()
        list_durationSeconds.name = "durationSeconds"
        list_durationSeconds.attributeType = .integer64AttributeType
        list_durationSeconds.isOptional = false

        let list_scheduleSlots = NSAttributeDescription()
        list_scheduleSlots.name = "scheduleSlots"
        list_scheduleSlots.attributeType = .binaryDataAttributeType
        list_scheduleSlots.isOptional = true

        let list_createdAt = NSAttributeDescription()
        list_createdAt.name = "createdAt"
        list_createdAt.attributeType = .dateAttributeType
        list_createdAt.isOptional = false

        let list_updatedAt = NSAttributeDescription()
        list_updatedAt.name = "updatedAt"
        list_updatedAt.attributeType = .dateAttributeType
        list_updatedAt.isOptional = false

        listEntity.properties = [list_id, list_name, list_protection, list_blockType, list_durationSeconds, list_scheduleSlots, list_createdAt, list_updatedAt]

        // BlockItemEntity
        let itemEntity = NSEntityDescription()
        itemEntity.name = "BlockItemEntity"
        itemEntity.managedObjectClassName = String(describing: BlockItemEntity.self)

        let item_id = NSAttributeDescription()
        item_id.name = "id"
        item_id.attributeType = .UUIDAttributeType
        item_id.isOptional = false

        let item_kind = NSAttributeDescription()
        item_kind.name = "kind"
        item_kind.attributeType = .stringAttributeType
        item_kind.isOptional = false

        let item_value = NSAttributeDescription()
        item_value.name = "value"
        item_value.attributeType = .stringAttributeType
        item_value.isOptional = false

        let item_displayName = NSAttributeDescription()
        item_displayName.name = "displayName"
        item_displayName.attributeType = .stringAttributeType
        item_displayName.isOptional = true

        // Relationships
        let rel_items = NSRelationshipDescription()
        rel_items.name = "items"
        rel_items.destinationEntity = itemEntity
        rel_items.minCount = 0
        rel_items.maxCount = 0 // to-many
        rel_items.deleteRule = .cascadeDeleteRule

        let rel_list = NSRelationshipDescription()
        rel_list.name = "list"
        rel_list.destinationEntity = listEntity
        rel_list.minCount = 0
        rel_list.maxCount = 1
        rel_list.deleteRule = .nullifyDeleteRule

        rel_items.inverseRelationship = rel_list
        rel_list.inverseRelationship = rel_items

        listEntity.properties.append(rel_items)
        itemEntity.properties = [item_id, item_kind, item_value, item_displayName, rel_list]

        model.entities = [listEntity, itemEntity]

        container = NSPersistentContainer(name: "Model", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Unresolved error: \(error)") }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

@main
struct blocking_appApp: App {
    private let core = CoreDataStack.shared

    init() {
        PersistenceMigration.runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, core.viewContext)
                .onAppear {
                    seedIfNeeded()
                }
        }
    }

    private func seedIfNeeded() {
        let key = AppStorageKeys.seedV1Done
        if UserDefaults.standard.bool(forKey: key) { return }
        let context = core.viewContext
        let names = ["Focus Time", "Sleep Time", "Deep Work"]
        for (idx, name) in names.enumerated() {
            let e = ListEntity(context: context)
            e.id = UUID()
            e.name = name
            e.protection = idx == 1 ? "hard" : "noProtection"
            e.blockType = "now"
            e.durationSeconds = Int64((idx + 1) * 1800)
            e.createdAt = Date().addingTimeInterval(-Double(idx) * 3600)
            e.updatedAt = Date()
        }
        switch context.saveIfNeeded() {
        case .success:
            UserDefaults.standard.set(true, forKey: key)
        case .failure:
            // Seed failure is non-fatal; user starts with empty list and can add manually.
            break
        }
    }
}
