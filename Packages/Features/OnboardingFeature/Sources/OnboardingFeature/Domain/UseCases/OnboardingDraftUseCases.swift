import Foundation

// MARK: - Save Onboarding Draft Use Case

public protocol SaveOnboardingDraftUseCaseProtocol {
    func execute(_ draft: OnboardingDraft, password: String?) async throws
}

public final class SaveOnboardingDraftUseCase: SaveOnboardingDraftUseCaseProtocol {
    private let repository: OnboardingRepositoryProtocol
    
    public init(repository: OnboardingRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(_ draft: OnboardingDraft, password: String?) async throws {
        try await repository.saveDraft(draft, password: password)
    }
}

// MARK: - Get Onboarding Draft Use Case

public protocol GetOnboardingDraftUseCaseProtocol {
    func execute() async throws -> (draft: OnboardingDraft, password: String?)?
}

public final class GetOnboardingDraftUseCase: GetOnboardingDraftUseCaseProtocol {
    private let repository: OnboardingRepositoryProtocol
    
    public init(repository: OnboardingRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute() async throws -> (draft: OnboardingDraft, password: String?)? {
        guard let result = try await repository.getDraft() else {
            return nil
        }
        
        // Don't return expired drafts
        if result.draft.isExpired {
            try await repository.clearDraft()
            return nil
        }
        
        return result
    }
}

// MARK: - Clear Onboarding Draft Use Case

public protocol ClearOnboardingDraftUseCaseProtocol {
    func execute() async throws
}

public final class ClearOnboardingDraftUseCase: ClearOnboardingDraftUseCaseProtocol {
    private let repository: OnboardingRepositoryProtocol
    
    public init(repository: OnboardingRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute() async throws {
        try await repository.clearDraft()
    }
}
