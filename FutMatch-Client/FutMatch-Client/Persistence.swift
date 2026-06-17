//
//  Persistence.swift
//  FutMatch-Client
//
//  Created by Gerardo Granados Lopez on 13/01/26.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        try? viewContext.save()
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FutMatch_Client")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure persistent store for production
            if let storeDescription = container.persistentStoreDescriptions.first {
                // Enable lightweight migration so schema changes (e.g. removing unused entities)
                // are applied automatically without requiring a mapping model.
                storeDescription.shouldMigrateStoreAutomatically = true
                storeDescription.shouldInferMappingModelAutomatically = true

                // Enable persistent history tracking
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                
                // Set file protection (iOS only)
                #if os(iOS)
                storeDescription.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, forKey: NSPersistentStoreFileProtectionKey)
                #endif
            }
        }

        container.loadPersistentStores(completionHandler: { _, _ in })
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
