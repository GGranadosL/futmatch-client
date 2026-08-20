import Foundation
import CoreData
import SharedModels

/// Factory for creating Onboarding dependencies
public struct OnboardingDependencyFactory {
    private let persistenceContainer: NSPersistentContainer
    private let countryRepository: CountryRepositoryProtocol
    private let dialCodeRepository: DialCodeRepositoryProtocol

    /// - Parameters:
    ///   - persistenceContainer: The shared CoreData container from PersistenceController.shared.container
    ///   - countryRepository: Country data source. Defaults to `FallbackCountryRepository`.
    ///   - dialCodeRepository: Dial-code data source. Defaults to `FallbackDialCodeRepository`.
    public init(persistenceContainer: NSPersistentContainer,
                countryRepository: CountryRepositoryProtocol = FallbackCountryRepository(),
                dialCodeRepository: DialCodeRepositoryProtocol = FallbackDialCodeRepository()) {
        self.persistenceContainer = persistenceContainer
        self.countryRepository = countryRepository
        self.dialCodeRepository = dialCodeRepository
    }

    // MARK: - Countries

    public func makeFetchCountriesUseCase() -> FetchCountriesUseCaseProtocol {
        FetchCountriesUseCase(repository: countryRepository)
    }

    // MARK: - Dial Codes

    public func makeFetchDialCodesUseCase() -> FetchDialCodesUseCaseProtocol {
        FetchDialCodesUseCase(repository: dialCodeRepository)
    }

    // MARK: - Google Auth

    public func makeSignInWithGoogleUseCase() -> SignInWithGoogleUseCaseProtocol {
        SignInWithGoogleUseCase(authService: AuthService())
    }

    /// - Parameter googleAuth: the Google SDK wrapper, owned by the app target —
    ///   it needs a presenting view controller, so it can't live in this package.
    public func makeRegisterGoogleUserUseCase(
        googleAuth: GoogleAuthProviding
    ) -> RegisterGoogleUserUseCaseProtocol {
        RegisterGoogleUserUseCase(authService: AuthService(), googleAuth: googleAuth)
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
            clearOnboardingDraftUseCase: makeClearOnboardingDraftUseCase(),
            fetchCountriesUseCase: makeFetchCountriesUseCase(),
            fetchDialCodesUseCase: makeFetchDialCodesUseCase()
        )
    }
}
