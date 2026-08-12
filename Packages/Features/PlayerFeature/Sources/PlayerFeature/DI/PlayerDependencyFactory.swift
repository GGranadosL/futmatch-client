import Foundation
import SharedModels
import AdminFeature

// MARK: - PlayerDependencyFactory

public struct PlayerDependencyFactory {
    private static let sharedMatchService      = MatchService(isDemoMode: false)
    private static let sharedDemoMatchService  = MatchService(isDemoMode: true)
    private static let sharedMatchVersionStore = UserDefaultsMatchVersionStore()
    private static let sharedNotificationFetchTimestampStore = UserDefaultsNotificationFetchTimestampStore()
    /// Shared across all ViewModels so every tab reuses the same resolved fix
    /// instead of each one racing its own CLLocationManager (see
    /// `CurrentLocationService`'s in-flight/caching logic).
    private static let sharedCurrentLocationService = CurrentLocationService()

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

    // MARK: - Field Attribute Catalog
    //
    // Reuses AdminFeature's catalog use case directly — same Remote Config
    // keys, same repository — so the terrain/footwear names shown here
    // always match what an admin picked when creating the field.

    func makeFetchFieldAttributeCatalogsUseCase() -> FetchFieldAttributeCatalogsUseCaseProtocol {
        AdminDependencyFactory().makeFetchFieldAttributeCatalogsUseCase()
    }

    // MARK: - Match Services

    func makeMatchService() -> MatchService {
        isDemoMode ? Self.sharedDemoMatchService : Self.sharedMatchService
    }

    func makeMatchVersionStore() -> MatchVersionStoreProtocol {
        Self.sharedMatchVersionStore
    }

    /// Clears all persisted regional matches versions. Call on logout so the
    /// next account re-fetches the full list instead of sending a stale
    /// `sinceVersion`.
    public func clearMatchVersions() {
        makeMatchVersionStore().clear()
    }

    func makeFetchMatchesUseCase() -> FetchMatchesUseCaseProtocol {
        FetchMatchesUseCase(
            matchService: makeMatchService(),
            versionStore: makeMatchVersionStore()
        )
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

    // MARK: - Location

    func makeCurrentLocationService() -> CurrentLocationProviding {
        Self.sharedCurrentLocationService
    }

    func makeDeviceLocationRepository() -> DeviceLocationRepositoryProtocol {
        DeviceLocationRepository(locationService: makeCurrentLocationService())
    }

    func makeFetchCurrentLocationUseCase() -> FetchCurrentLocationUseCaseProtocol {
        FetchCurrentLocationUseCase(repository: makeDeviceLocationRepository())
    }

    // MARK: - Payment Services

    func makePaymentService() -> PaymentServiceProtocol {
        PaymentService()
    }

    func makePollPaymentStatusUseCase() -> PollPaymentStatusUseCaseProtocol {
        PollPaymentStatusUseCase(paymentService: makePaymentService())
    }

    func makePendingPaymentStore() -> PendingPaymentStoreProtocol {
        KeychainPendingPaymentStore()
    }

    func makeFetchPendingMatchPaymentUseCase() -> FetchPendingMatchPaymentUseCaseProtocol {
        FetchPendingMatchPaymentUseCase(
            paymentService: makePaymentService(),
            isDemoMode: isDemoMode
        )
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

    // MARK: - Account

    func makeAccountService() -> AccountServiceProtocol {
        AccountService()
    }

    func makeAccountRepository() -> AccountRepositoryProtocol {
        AccountRepository(service: makeAccountService())
    }

    func makeDeleteAccountUseCase() -> DeleteAccountUseCaseProtocol {
        DeleteAccountUseCase(repository: makeAccountRepository())
    }

    @MainActor
    func makePlayerProfileViewModel(userId: String) -> PlayerProfileViewModel {
        PlayerProfileViewModel(
            userId: userId,
            profileService: makeProfileService(),
            fetchMatchDetailUseCase: makeFetchMatchDetailUseCase()
        )
    }

    // MARK: - Notifications

    @MainActor
    func makeNotificationsViewModel() -> NotificationsViewModel {
        let service: NotificationServiceProtocol = isDemoMode
            ? DemoNotificationService()
            : NotificationService()
        let fetchNotificationsUseCase = FetchNotificationsUseCase(
            notificationService: service,
            timestampStore: Self.sharedNotificationFetchTimestampStore
        )
        return NotificationsViewModel(
            notificationService: service,
            fetchNotificationsUseCase: fetchNotificationsUseCase,
            fetchMatchDetailUseCase: makeFetchMatchDetailUseCase()
        )
    }
}
