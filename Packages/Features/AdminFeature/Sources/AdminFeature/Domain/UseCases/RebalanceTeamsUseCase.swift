// MARK: - Rebalance Teams Use Case Protocol

protocol RebalanceTeamsUseCaseProtocol {
    func execute(matchId: String, assignments: [(userId: String, team: String)]) async throws
}

// MARK: - Rebalance Teams Use Case

struct RebalanceTeamsUseCase: RebalanceTeamsUseCaseProtocol {
    private let repository: AdminMatchRepositoryProtocol

    init(repository: AdminMatchRepositoryProtocol) {
        self.repository = repository
    }

    func execute(matchId: String, assignments: [(userId: String, team: String)]) async throws {
        try await repository.rebalanceTeams(matchId: matchId, assignments: assignments)
    }
}
