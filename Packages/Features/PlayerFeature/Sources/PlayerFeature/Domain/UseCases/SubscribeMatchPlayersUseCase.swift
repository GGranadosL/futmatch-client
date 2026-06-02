// MARK: - Subscribe Match Players Use Case Protocol

protocol SubscribeMatchPlayersUseCaseProtocol {
    func execute(matchId: String) -> AsyncStream<MatchPlayersSnapshot>
}

// MARK: - Subscribe Match Players Use Case

final class SubscribeMatchPlayersUseCase: SubscribeMatchPlayersUseCaseProtocol {
    private let repository: MatchPlayersListenerProtocol

    init(repository: MatchPlayersListenerProtocol) {
        self.repository = repository
    }

    func execute(matchId: String) -> AsyncStream<MatchPlayersSnapshot> {
        repository.playerStream(matchId: matchId)
    }
}
