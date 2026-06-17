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

    func cancelMatch(matchId: String) async throws {
        try await service.cancelMatch(matchId: matchId)
    }
}
