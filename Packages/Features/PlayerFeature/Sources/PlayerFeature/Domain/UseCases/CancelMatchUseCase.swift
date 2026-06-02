// MARK: - Cancel Match Use Case Protocol

protocol CancelMatchUseCaseProtocol {
    func execute(matchId: String) async throws
}

// MARK: - Cancel Match Use Case

final class CancelMatchUseCase: CancelMatchUseCaseProtocol {
    private let matchService: MatchServiceProtocol

    init(matchService: MatchServiceProtocol) {
        self.matchService = matchService
    }

    func execute(matchId: String) async throws {
        try await matchService.cancelMatch(id: matchId)
    }
}
