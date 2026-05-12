import Foundation

// MARK: - HomeDependencyFactory

public struct HomeDependencyFactory {
    private static let sharedMatchService: MatchServiceProtocol = MatchService()

    public init() {}

    // MARK: - Services

    public func makeDeviceService() -> DeviceServiceProtocol {
        DeviceService()
    }

    // MARK: - Use Cases

    public func makeUpdateFCMTokenUseCase() -> UpdateFCMTokenUseCaseProtocol {
        UpdateFCMTokenUseCase(deviceService: makeDeviceService())
    }

    // MARK: - Match Services

    func makeMatchService() -> MatchServiceProtocol {
        Self.sharedMatchService
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
}
