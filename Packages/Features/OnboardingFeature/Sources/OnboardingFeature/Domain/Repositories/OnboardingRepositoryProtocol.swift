import Foundation

/// Protocol for Onboarding data persistence
public protocol OnboardingRepositoryProtocol {
    /// Save onboarding draft data
    /// - Parameters:
    ///   - draft: The onboarding draft data
    ///   - password: Optional password to save securely in Keychain
    func saveDraft(_ draft: OnboardingDraft, password: String?) async throws
    
    /// Get saved onboarding draft
    /// - Returns: Tuple with draft and password (if saved), or nil if no draft exists
    func getDraft() async throws -> (draft: OnboardingDraft, password: String?)?
    
    /// Clear saved onboarding draft
    func clearDraft() async throws
}
