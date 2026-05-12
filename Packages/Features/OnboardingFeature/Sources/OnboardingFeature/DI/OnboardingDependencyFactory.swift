import Foundation
import CoreData

/// Factory for creating Onboarding dependencies
public struct OnboardingDependencyFactory {
    private let persistenceContainer: NSPersistentContainer
    
    /// Initialize with the app's shared NSPersistentContainer
    /// - Parameter persistenceContainer: The shared CoreData container from PersistenceController.shared.container
    public init(persistenceContainer: NSPersistentContainer) {
        self.persistenceContainer = persistenceContainer
    }
    
    // MARK: - Repository
    
    public func makeOnboardingRepository() -> OnboardingRepositoryProtocol {
        OnboardingRepository(
            container: persistenceContainer,
            keychainManager: .shared
        )
    }
    
    // MARK: - Use Cases
    
    public func makeSaveOnboardingDraftUseCase() -> SaveOnboardingDraftUseCaseProtocol {
        SaveOnboardingDraftUseCase(repository: makeOnboardingRepository())
    }
    
    public func makeGetOnboardingDraftUseCase() -> GetOnboardingDraftUseCaseProtocol {
        GetOnboardingDraftUseCase(repository: makeOnboardingRepository())
    }
    
    public func makeClearOnboardingDraftUseCase() -> ClearOnboardingDraftUseCaseProtocol {
        ClearOnboardingDraftUseCase(repository: makeOnboardingRepository())
    }
    
    // MARK: - ViewModel
    
    @MainActor public func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            saveOnboardingDraftUseCase: makeSaveOnboardingDraftUseCase(),
            getOnboardingDraftUseCase: makeGetOnboardingDraftUseCase(),
            clearOnboardingDraftUseCase: makeClearOnboardingDraftUseCase()
        )
    }
}
