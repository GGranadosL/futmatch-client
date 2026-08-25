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
    /// - Parameter socialIdentity: the social account currently signing up, or
    ///   `nil` for the email/password flow.
    func execute(socialIdentity: SocialDraftIdentity?) async throws -> (draft: OnboardingDraft, password: String?)?
}

public final class GetOnboardingDraftUseCase: GetOnboardingDraftUseCaseProtocol {
    private let repository: OnboardingRepositoryProtocol

    public init(repository: OnboardingRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(socialIdentity: SocialDraftIdentity?) async throws -> (draft: OnboardingDraft, password: String?)? {
        guard let result = try await repository.getDraft() else {
            return nil
        }

        // Don't return expired drafts
        if result.draft.isExpired {
            try await repository.clearDraft()
            return nil
        }

        // Only one draft row exists, so every sign-up flow shares it. Handing the
        // wrong one back is not a cosmetic problem: a social draft restored into
        // the password flow builds a registration with no password, a password
        // draft restored into a social flow prefills a stranger's details, and a
        // Google draft restored into an Apple flow (or vice versa) is exactly as
        // wrong as mixing up two different Google accounts. Either way the next
        // save overwrites the row, so a mismatch just starts clean rather than
        // clearing anything here.
        guard matches(result.draft, socialIdentity) else { return nil }

        return result
    }

    private func matches(_ draft: OnboardingDraft, _ socialIdentity: SocialDraftIdentity?) -> Bool {
        switch (socialIdentity, draft.socialIdentity) {
        case (nil, nil):
            return true
        case let (requested?, stored?):
            return requested == stored
        default:
            return false
        }
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
