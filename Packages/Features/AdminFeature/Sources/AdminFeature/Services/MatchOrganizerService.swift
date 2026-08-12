import Foundation
import NetworkFramework

// MARK: - Protocol

protocol MatchOrganizerServiceProtocol {
    func fetchAllMatches() async throws -> [AdminMatch]
}

// MARK: - Implementation

struct MatchOrganizerService: MatchOrganizerServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// Same payload shape as `/match/admin/matches`, scoped to the matches the
    /// signed-in organizer supervises — so it decodes with the admin list DTO.
    func fetchAllMatches() async throws -> [AdminMatch] {
        let response: AdminMatchListResponseDTO = try await apiClient.request(
            endpoint: MatchOrganizerEndpoint.fetchAll
        )
        return response.data.map { $0.toDomain() }
    }
}
