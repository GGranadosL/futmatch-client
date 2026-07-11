import Foundation

struct AdminMatchRepository: AdminMatchRepositoryProtocol {
    private let service: MatchAdminServiceProtocol

    init(service: MatchAdminServiceProtocol) {
        self.service = service
    }

    func fetchMatches() async throws -> [AdminMatch] {
        try await service.fetchAllMatches()
    }

    func createMatch(_ params: CreateMatchParams) async throws -> AdminMatch {
        try await service.createMatch(params)
    }

    func updateMatch(_ params: UpdateMatchParams) async throws -> AdminMatch {
        try await service.updateMatch(params)
    }

    func cancelMatch(matchId: String, reason: String) async throws {
        try await service.cancelMatch(matchId: matchId, reason: reason)
    }

    func completeMatch(params: CompleteMatchParams) async throws {
        try await service.completeMatch(params: params)
    }

    func fetchMatchPlayers(matchId: String) async throws -> (teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer]) {
        try await service.fetchMatchDetail(matchId: matchId)
    }

    func rebalanceTeams(matchId: String, assignments: [(userId: String, team: String)]) async throws {
        let players = assignments.map { PlayerTeamAssignmentDTO(userId: $0.userId, team: $0.team) }
        try await service.rebalanceTeams(matchId: matchId, players: players)
    }
}
