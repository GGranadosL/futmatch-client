import Foundation

// MARK: - Protocol

protocol JoinMatchUseCaseProtocol {
    func execute(matchId: String, team: String?) async throws -> JoinMatchData
}

// MARK: - Implementation

final class JoinMatchUseCase: JoinMatchUseCaseProtocol {
    private let matchService: MatchServiceProtocol

    init(matchService: MatchServiceProtocol) {
        self.matchService = matchService
    }

    func execute(matchId: String, team: String?) async throws -> JoinMatchData {
        try await matchService.joinMatch(id: matchId, team: team)
    }
}
