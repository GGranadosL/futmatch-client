import Foundation

protocol AdminMatchRepositoryProtocol {
    func fetchMatches() async throws -> [AdminMatch]
    func createMatch(_ params: CreateMatchParams) async throws -> AdminMatch
    func updateMatch(_ params: UpdateMatchParams) async throws -> AdminMatch
    func cancelMatch(matchId: String, reason: String) async throws
    func completeMatch(params: CompleteMatchParams) async throws
    func fetchMatchPlayers(matchId: String) async throws -> (teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer])
    func rebalanceTeams(matchId: String, assignments: [(userId: String, team: String)]) async throws
}
