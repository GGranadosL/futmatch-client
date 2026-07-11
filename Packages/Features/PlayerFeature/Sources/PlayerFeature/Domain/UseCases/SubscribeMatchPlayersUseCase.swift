// MARK: - Subscribe Match Players Use Case Protocol

protocol SubscribeMatchPlayersUseCaseProtocol {
    func execute(matchId: String) -> AsyncThrowingStream<MatchPlayersSnapshot, Error>
}

// MARK: - Subscribe Match Players Use Case

final class SubscribeMatchPlayersUseCase: SubscribeMatchPlayersUseCaseProtocol {
    private let repository: MatchPlayersListenerProtocol

    init(repository: MatchPlayersListenerProtocol) {
        self.repository = repository
    }

    func execute(matchId: String) -> AsyncThrowingStream<MatchPlayersSnapshot, Error> {
        repository.playerStream(matchId: matchId)
    }
}
