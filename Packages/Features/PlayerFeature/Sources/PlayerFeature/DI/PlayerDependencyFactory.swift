import Foundation
import SharedModels
import AdminFeature

// MARK: - PlayerDependencyFactory

public struct PlayerDependencyFactory {
    private static let sharedMatchService      = MatchService(isDemoMode: false)
    private static let sharedDemoMatchService  = MatchService(isDemoMode: true)
    private static let sharedMatchVersionStore = UserDefaultsMatchVersionStore()
    private static let sharedNotificationCacheStore = UserDefaultsNotificationCacheStore()
    /// Shared across all ViewModels so every tab reuses the same resolved fix
    /// instead of each one racing its own CLLocationManager (see
    /// `CurrentLocationService`'s in-flight/caching logic).
    private static let sharedCurrentLocationService = CurrentLocationService(
        makeLocationManager: { CoreLocationManager() }
    )
    private static let sharedPaymentSecurityPreferenceStore = UserDefaultsPaymentSecurityPreferenceStore()

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

    /// The only place that reads the process-wide tracker; view models get it by init.
    func makeAnalytics() -> AnalyticsTracking {
        AnalyticsRegistry.current
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

    func makeBiometricAuthenticator() -> BiometricAuthenticating {
        BiometricAuthenticator()
    }

    func makeConfirmLocalIdentityUseCase() -> ConfirmLocalIdentityUseCaseProtocol {
        ConfirmLocalIdentityUseCase(authenticator: makeBiometricAuthenticator())
    }

    @MainActor
    func makePlayerProfileViewModel(userId: String) -> PlayerProfileViewModel {
        PlayerProfileViewModel(
            userId: userId,
            profileService: makeProfileService(),
            fetchMatchDetailUseCase: makeFetchMatchDetailUseCase()
        )
    }

    // MARK: - Payment Security

    func makePaymentSecurityPreferenceStore() -> PaymentSecurityPreferenceStoring {
        Self.sharedPaymentSecurityPreferenceStore
    }

    func makeAuthorizeSensitiveActionUseCase() -> AuthorizeSensitiveActionUseCaseProtocol {
        AuthorizeSensitiveActionUseCase(
            preferenceStore: makePaymentSecurityPreferenceStore(),
            confirmIdentityUseCase: makeConfirmLocalIdentityUseCase()
        )
    }

    func makeGetPaymentSecurityEnabledUseCase() -> GetPaymentSecurityEnabledUseCaseProtocol {
        GetPaymentSecurityEnabledUseCase(store: makePaymentSecurityPreferenceStore())
    }

    func makeSetPaymentSecurityEnabledUseCase() -> SetPaymentSecurityEnabledUseCaseProtocol {
        SetPaymentSecurityEnabledUseCase(store: makePaymentSecurityPreferenceStore())
    }

    @MainActor
    func makePaymentSecurityViewModel() -> PaymentSecurityViewModel {
        PaymentSecurityViewModel(
            getEnabledUseCase: makeGetPaymentSecurityEnabledUseCase(),
            setEnabledUseCase: makeSetPaymentSecurityEnabledUseCase(),
            authorizeUseCase: makeAuthorizeSensitiveActionUseCase()
        )
    }

    // MARK: - Notifications

    func makeNotificationRepository() -> NotificationRepositoryProtocol {
        let service: NotificationServiceProtocol = isDemoMode
            ? DemoNotificationService()
            : NotificationService()
        return NotificationRepository(service: service, cache: Self.sharedNotificationCacheStore)
    }

    @MainActor
    func makeNotificationsViewModel() -> NotificationsViewModel {
        let repository = makeNotificationRepository()
        return NotificationsViewModel(
            loadCachedUseCase: LoadCachedNotificationsUseCase(repository: repository),
            fetchUnreadCountUseCase: FetchUnreadNotificationCountUseCase(repository: repository),
            openInboxUseCase: OpenNotificationInboxUseCase(repository: repository),
            refreshInboxUseCase: RefreshNotificationInboxUseCase(repository: repository),
            deleteNotificationUseCase: DeleteNotificationUseCase(repository: repository),
            registerIncomingUseCase: RegisterIncomingNotificationUseCase(repository: repository),
            clearStateUseCase: ClearNotificationStateUseCase(repository: repository),
            fetchMatchDetailUseCase: makeFetchMatchDetailUseCase()
        )
    }

    /// Clears the notification history, the unread counter and the cache timestamp.
    /// Call on logout so the next account starts from scratch and never sees this
    /// account's badge.
    public func clearNotificationState() {
        ClearNotificationStateUseCase(repository: makeNotificationRepository()).execute()
    }
}
