import Foundation

// MARK: - Params

struct CompleteMatchParams {
    struct PlayerGoal {
        let userId: String
        let goals: Int
    }
    struct ExternalTeamGoals {
        let team: String  // "A" or "B"
        let goals: Int
    }
    let matchId: String
    let bestPlayerId: String
    let playerGoals: [PlayerGoal]
    let externalGoals: [ExternalTeamGoals]
}

// MARK: - Protocol

protocol CompleteMatchUseCaseProtocol {
    func execute(params: CompleteMatchParams) async throws
}

// MARK: - Implementation

struct CompleteMatchUseCase: CompleteMatchUseCaseProtocol {
    private let repository: AdminMatchRepositoryProtocol

    init(repository: AdminMatchRepositoryProtocol) {
        self.repository = repository
    }

    func execute(params: CompleteMatchParams) async throws {
        try await repository.completeMatch(params: params)
    }
}
