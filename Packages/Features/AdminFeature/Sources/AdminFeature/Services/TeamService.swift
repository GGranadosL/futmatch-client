import Foundation
import NetworkFramework

protocol TeamServiceProtocol {
    func fetchTeamCatalog() async throws -> [TeamVisualCatalogItem]
}

struct TeamService: TeamServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchTeamCatalog() async throws -> [TeamVisualCatalogItem] {
        let response: TeamCatalogResponseDTO = try await apiClient.request(endpoint: TeamEndpoint.catalog)
        return response.data.map { $0.toDomain() }
    }
}
