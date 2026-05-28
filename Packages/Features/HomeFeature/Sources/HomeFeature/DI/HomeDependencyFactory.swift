import Foundation
import SharedModels

// MARK: - HomeDependencyFactory

public struct HomeDependencyFactory {
    private static let sharedMatchService      = MatchService(isDemoMode: false)
    private static let sharedDemoMatchService  = MatchService(isDemoMode: true)

    private let isDemoMode: Bool
    private let countryRepository: CountryRepositoryProtocol

    public init(isDemoMode: Bool = false,
                countryRepository: CountryRepositoryProtocol = FallbackCountryRepository()) {
        self.isDemoMode = isDemoMode
        self.countryRepository = countryRepository
    }

    // MARK: - Countries

    public func makeFetchCountriesUseCase() -> FetchCountriesUseCaseProtocol {
        FetchCountriesUseCase(repository: countryRepository)
    }

    // MARK: - Services

    public func makeDeviceService() -> DeviceServiceProtocol {
        DeviceService()
    }

    // MARK: - Use Cases

    public func makeUpdateFCMTokenUseCase() -> UpdateFCMTokenUseCaseProtocol {
        UpdateFCMTokenUseCase(deviceService: makeDeviceService())
    }

    // MARK: - Match Services

    func makeMatchService() -> MatchService {
        isDemoMode ? Self.sharedDemoMatchService : Self.sharedMatchService
    }

    func makeFetchMatchesUseCase() -> FetchMatchesUseCaseProtocol {
        FetchMatchesUseCase(matchService: makeMatchService())
    }

    func makeFetchMatchDetailUseCase() -> FetchMatchDetailUseCaseProtocol {
        FetchMatchDetailUseCase(matchService: makeMatchService())
    }

    func makeJoinMatchUseCase() -> JoinMatchUseCaseProtocol {
        JoinMatchUseCase(matchService: makeMatchService())
    }

    func makeSubscribeMatchPlayersUseCase() -> SubscribeMatchPlayersUseCaseProtocol {
        SubscribeMatchPlayersUseCase(repository: FirestoreMatchPlayersRepository())
    }

    func makeCancelMatchUseCase() -> CancelMatchUseCaseProtocol {
        CancelMatchUseCase(matchService: makeMatchService())
    }

    func makeLeaveMatchUseCase() -> LeaveMatchUseCaseProtocol {
        LeaveMatchUseCase(matchService: makeMatchService())
    }

    func makeFetchMyMatchesUseCase() -> FetchMyMatchesUseCaseProtocol {
        FetchMyMatchesUseCase(matchService: makeMatchService())
    }

    // MARK: - Payment Services

    func makePaymentService() -> PaymentServiceProtocol {
        PaymentService()
    }

    @MainActor
    func makePaymentMethodsViewModel() -> PaymentMethodsViewModel {
        PaymentMethodsViewModel(paymentService: makePaymentService())
    }

    @MainActor
    func makePaymentHistoryViewModel() -> PaymentHistoryViewModel {
        PaymentHistoryViewModel(paymentService: makePaymentService())
    }

    // MARK: - Player Profile

    func makeProfileService() -> ProfileServiceProtocol {
        ProfileService()
    }

    @MainActor
    func makePlayerProfileViewModel(userId: String) -> PlayerProfileViewModel {
        PlayerProfileViewModel(userId: userId, profileService: makeProfileService())
    }

    // MARK: - Notifications

    @MainActor
    func makeNotificationsViewModel() -> NotificationsViewModel {
        let service: NotificationServiceProtocol = isDemoMode
            ? DemoNotificationService()
            : NotificationService()
        return NotificationsViewModel(
            notificationService: service,
            fetchMatchDetailUseCase: makeFetchMatchDetailUseCase()
        )
    }
}
