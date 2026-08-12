import Foundation

struct OrganizerMatchRepository: OrganizerMatchRepositoryProtocol {
    private let service: MatchOrganizerServiceProtocol

    init(service: MatchOrganizerServiceProtocol) {
        self.service = service
    }

    func fetchMatches() async throws -> [AdminMatch] {
        try await service.fetchAllMatches()
    }
}
