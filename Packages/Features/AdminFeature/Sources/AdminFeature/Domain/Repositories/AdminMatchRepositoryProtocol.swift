import Foundation

protocol AdminMatchRepositoryProtocol {
    func fetchMatches() async throws -> [AdminMatch]
    func createMatch(_ params: CreateMatchParams) async throws -> AdminMatch
    func cancelMatch(matchId: String) async throws
}
