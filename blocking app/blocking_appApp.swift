//
//  blocking_appApp.swift
//  blocking app
//
//  Created by Khalid Khamid on 12/03/1447 AH.
//

import SwiftUI
import CoreData
import os

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

        let list_gatekeeperType = NSAttributeDescription()
        list_gatekeeperType.name = "gatekeeperType"
        list_gatekeeperType.attributeType = .stringAttributeType
        list_gatekeeperType.isOptional = false
        // Default value — applied to new entities AND to existing rows
        // that pre-date this attribute on next save (Core Data lightweight
        // migration is automatic for added non-optional attributes with
        // a default value).
        list_gatekeeperType.defaultValue = "nonet"

        listEntity.properties = [list_id, list_name, list_protection, list_blockType, list_durationSeconds, list_scheduleSlots, list_createdAt, list_updatedAt, list_gatekeeperType]

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

        let newContainer = NSPersistentContainer(name: "Model", managedObjectModel: model)
        newContainer.loadPersistentStores { _, error in
            if let error = error {
                // The store file is unreadable — typically a corrupted SQLite
                // (rare; can happen after an aborted migration or disk-full
                // crash mid-write). The Apple-recommended fallback for a
                // model we own end-to-end is: delete the file, reload fresh.
                // The user loses local lists but the app still launches,
                // which beats a hard crash on every launch.
                //
                // We do NOT fatalError in production: an unbootable app on
                // App Store has no recovery path for the user other than
                // reinstall. A fresh empty store at least lets them recreate
                // their lists. CloudKit-stored data (partnerships, break
                // attempts) is untouched — it lives on iCloud, not in the
                // local store.
                Self.log.error("Core Data load failed: \(error.localizedDescription, privacy: .public). Attempting fresh-store recovery.")
                Self.recoverFromCorruptStore(container: newContainer)
            }
        }
        container = newContainer
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static let log = Logger(subsystem: "app.nonet.blocking", category: "CoreDataStack")

    /// Delete every persistent store the container knows about and reload
    /// fresh. Called only when the initial loadPersistentStores threw. If
    /// recovery itself fails (e.g. read-only filesystem), we fall through
    /// to fatalError — at that point the device is in worse shape than the
    /// app can handle, and a clean crash is better than a half-working app.
    private static func recoverFromCorruptStore(container: NSPersistentContainer) {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            if let url = store.url {
                try? coordinator.remove(store)
                try? FileManager.default.removeItem(at: url)
                // SQLite also drops -shm and -wal sidecars; clean them up so
                // the next load doesn't reattach to a half-deleted store.
                let parent = url.deletingLastPathComponent()
                let base = url.lastPathComponent
                ["\(base)-shm", "\(base)-wal"].forEach { sidecar in
                    try? FileManager.default.removeItem(at: parent.appendingPathComponent(sidecar))
                }
            }
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data fresh-store reload also failed: \(error)")
            }
            log.notice("Core Data recovered with fresh empty store")
        }
    }
}

@main
struct blocking_appApp: App {
    // Adopts UIApplicationDelegate solely so iOS routes CloudKit share-acceptance
    // through PartnerSceneDelegate.windowScene(_:userDidAcceptCloudKitShareWith:).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
