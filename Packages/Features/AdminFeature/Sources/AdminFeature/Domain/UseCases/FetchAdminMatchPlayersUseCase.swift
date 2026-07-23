import Foundation

protocol FetchAdminMatchPlayersUseCaseProtocol {
    func execute(matchId: String) async throws -> (teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer])
}

struct FetchAdminMatchPlayersUseCase: FetchAdminMatchPlayersUseCaseProtocol {
    private let repository: AdminMatchRepositoryProtocol

    init(repository: AdminMatchRepositoryProtocol) {
        self.repository = repository
    }

    func execute(matchId: String) async throws -> (teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer]) {
        try await repository.fetchMatchPlayers(matchId: matchId)
    }
}
