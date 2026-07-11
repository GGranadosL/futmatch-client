// MARK: - Subscribe Admin Match Players Use Case Protocol

protocol SubscribeAdminMatchPlayersUseCaseProtocol {
    func execute(matchId: String) -> AsyncThrowingStream<AdminMatchPlayersSnapshot, Error>
}

// MARK: - Subscribe Admin Match Players Use Case

struct SubscribeAdminMatchPlayersUseCase: SubscribeAdminMatchPlayersUseCaseProtocol {
    private let repository: AdminMatchPlayersListenerProtocol

    init(repository: AdminMatchPlayersListenerProtocol) {
        self.repository = repository
    }

    func execute(matchId: String) -> AsyncThrowingStream<AdminMatchPlayersSnapshot, Error> {
        repository.playerStream(matchId: matchId)
    }
}
