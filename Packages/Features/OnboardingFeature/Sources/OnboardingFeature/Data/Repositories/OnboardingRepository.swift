import Foundation
import CoreData
import PersistenceFramework

public final class OnboardingRepository: OnboardingRepositoryProtocol {
    private let container: NSPersistentContainer
    private let keychainManager: KeychainManager
    private let passwordKey = "onboarding_draft_password"
    
    public init(container: NSPersistentContainer, keychainManager: KeychainManager = .shared) {
        self.container = container
        self.keychainManager = keychainManager
    }
    
    // MARK: - Save Draft
    
    public func saveDraft(_ draft: OnboardingDraft, password: String?) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        try await context.perform {
            // Delete existing drafts (only keep one)
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "OnboardingDraftEntity")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                // Merge changes to view context
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [self.container.viewContext]
                )
            }
            
            // Create new draft entity
            let entity = NSEntityDescription.insertNewObject(forEntityName: "OnboardingDraftEntity", into: context)
            entity.setValue(draft.firstName, forKey: "firstName")
            entity.setValue(draft.lastName, forKey: "lastName")
            entity.setValue(draft.birthDate, forKey: "birthDate")
            entity.setValue(draft.gender, forKey: "gender")
            entity.setValue(draft.email, forKey: "email")
            entity.setValue(draft.phoneCountryCode, forKey: "phoneCountryCode")
            entity.setValue(draft.phone, forKey: "phone")
            entity.setValue(draft.country, forKey: "country")
            entity.setValue(Int16(draft.currentStep), forKey: "currentStep")
            entity.setValue(draft.createdAt, forKey: "createdAt")
            entity.setValue(Date(), forKey: "updatedAt")
            
            // Save to persistent store
            if context.hasChanges {
                try context.save()
            }
        }

        // Save password in Keychain (secure)
        if let password = password, !password.isEmpty {
            try keychainManager.save(password, forKey: passwordKey)
        }
    }
    
    // MARK: - Get Draft
    
    public func getDraft() async throws -> (draft: OnboardingDraft, password: String?)? {
        let context = container.viewContext
        
        let result: NSManagedObject? = try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "OnboardingDraftEntity")
            fetchRequest.fetchLimit = 1
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            
            let results = try context.fetch(fetchRequest)
            return results.first
        }

        guard let entity = result else {
            return nil
        }
        
        let draft = OnboardingDraft(
            firstName: entity.value(forKey: "firstName") as? String ?? "",
            lastName: entity.value(forKey: "lastName") as? String ?? "",
            birthDate: entity.value(forKey: "birthDate") as? Date,
            gender: entity.value(forKey: "gender") as? String,
            email: entity.value(forKey: "email") as? String ?? "",
            phoneCountryCode: entity.value(forKey: "phoneCountryCode") as? String ?? "+52",
            phone: entity.value(forKey: "phone") as? String ?? "",
            country: entity.value(forKey: "country") as? String ?? "",
            currentStep: Int(entity.value(forKey: "currentStep") as? Int16 ?? 1),
            createdAt: entity.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: entity.value(forKey: "updatedAt") as? Date ?? Date()
        )
        
        // Check expiration
        if draft.isExpired {
            try await clearDraft()
            return nil
        }
        
        // Get password from Keychain
        let password = try? keychainManager.retrieve(forKey: passwordKey)
        
        return (draft, password)
    }
    
    // MARK: - Clear Draft
    
    public func clearDraft() async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "OnboardingDraftEntity")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                // Merge changes to view context
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [self.container.viewContext]
                )
            }
            
            if context.hasChanges {
                try context.save()
            }
        }

        // Clear password from Keychain
        try? keychainManager.delete(forKey: passwordKey)
    }
}
