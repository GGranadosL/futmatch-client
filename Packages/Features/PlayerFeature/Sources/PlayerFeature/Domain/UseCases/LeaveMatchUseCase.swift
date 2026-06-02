// MARK: - Leave Match Use Case Protocol

protocol LeaveMatchUseCaseProtocol {
    func execute(matchId: String) async throws
}

// MARK: - Leave Match Use Case

final class LeaveMatchUseCase: LeaveMatchUseCaseProtocol {
    private let matchService: MatchServiceProtocol

    init(matchService: MatchServiceProtocol) {
        self.matchService = matchService
    }

    func execute(matchId: String) async throws {
        try await matchService.leaveMatch(id: matchId)
    }
}
