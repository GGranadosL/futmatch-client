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
    /// Enrolled active players who did not attend. Recorded as NO_SHOW by the backend;
    /// every enrolled player not listed is recorded as PRESENT.
    let absentPlayerIds: [String]
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
