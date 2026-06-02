import Foundation

// MARK: - Protocol

protocol FetchMatchDetailUseCaseProtocol {
    func execute(matchId: String) async throws -> MatchItem
}

// MARK: - Implementation

final class FetchMatchDetailUseCase: FetchMatchDetailUseCaseProtocol {
    private let matchService: MatchServiceProtocol

    init(matchService: MatchServiceProtocol) {
        self.matchService = matchService
    }

    func execute(matchId: String) async throws -> MatchItem {
        try await matchService.fetchMatchDetail(id: matchId)
    }
}
