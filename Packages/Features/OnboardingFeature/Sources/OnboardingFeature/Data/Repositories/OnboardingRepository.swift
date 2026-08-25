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
            entity.socialProvider = draft.provider?.rawValue
            entity.socialIssuer = draft.socialIssuer
            entity.socialSubject = draft.socialSubject
            entity.socialPictureURL = draft.socialPictureURL
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

        // Rows written before this build carry `socialIssuer`/`socialSubject`
        // (renamed at the CoreData level from `googleIssuer`/`googleSubject`) but
        // no `socialProvider`, since that column didn't exist yet. Every draft
        // written back then could only have come from Google, so infer it from
        // the issuer rather than losing the identity outright.
        let provider = entity.socialProvider.flatMap(AuthProvider.init(rawValue:))
            ?? (entity.socialIssuer == AuthProvider.google.issuer ? .google : nil)

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
            provider: provider,
            socialIssuer: entity.socialIssuer,
            socialSubject: entity.socialSubject,
            socialPictureURL: entity.socialPictureURL,
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
