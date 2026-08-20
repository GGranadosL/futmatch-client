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
            // Delete existing drafts (only keep one).
            // NSBatchDeleteRequest is used here because this is a background context with
            // an explicit mergeChanges call — the normal crash-prone pattern does not apply.
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: OnboardingDraftEntity.deleteFetchRequest())
            deleteRequest.resultType = .resultTypeObjectIDs
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [self.container.viewContext]
                )
            }

            let entity = OnboardingDraftEntity(context: context)
            entity.firstName = draft.firstName
            entity.lastName = draft.lastName
            entity.birthDate = draft.birthDate
            entity.gender = draft.gender
            entity.email = draft.email
            entity.phoneCountryCode = draft.phoneCountryCode
            entity.phone = draft.phone
            entity.country = draft.country
            // `countryISO` was previously dropped here, so a restored draft came
            // back with the country name filled but no ISO code — leaving step 2
            // silently invalid. Persisted now that the entity carries the field.
            entity.countryISO = draft.countryISO
            entity.currentStep = Int16(draft.currentStep)
            entity.googleIssuer = draft.googleIssuer
            entity.googleSubject = draft.googleSubject
            entity.googlePictureURL = draft.googlePictureURL
            entity.createdAt = draft.createdAt
            entity.updatedAt = Date()

            if context.hasChanges { try context.save() }
        }

        if let password = password, !password.isEmpty {
            try keychainManager.save(password, forKey: passwordKey)
        }
    }

    // MARK: - Get Draft

    public func getDraft() async throws -> (draft: OnboardingDraft, password: String?)? {
        let context = container.viewContext

        let result: OnboardingDraftEntity? = try await context.perform {
            let request = OnboardingDraftEntity.fetchRequest()
            request.fetchLimit = 1
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).first
        }

        guard let entity = result else { return nil }

        let draft = OnboardingDraft(
            firstName: entity.firstName,
            lastName: entity.lastName,
            birthDate: entity.birthDate,
            gender: entity.gender,
            email: entity.email,
            phoneCountryCode: entity.phoneCountryCode,
            phone: entity.phone,
            country: entity.country,
            countryISO: entity.countryISO ?? "",
            currentStep: Int(entity.currentStep),
            googleIssuer: entity.googleIssuer,
            googleSubject: entity.googleSubject,
            googlePictureURL: entity.googlePictureURL,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )

        if draft.isExpired {
            try await clearDraft()
            return nil
        }

        let password = try? keychainManager.retrieve(forKey: passwordKey)
        return (draft, password)
    }

    // MARK: - Clear Draft

    public func clearDraft() async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        try await context.perform {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: OnboardingDraftEntity.deleteFetchRequest())
            deleteRequest.resultType = .resultTypeObjectIDs
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [self.container.viewContext]
                )
            }
            if context.hasChanges { try context.save() }
        }

        try? keychainManager.delete(forKey: passwordKey)
    }
}
