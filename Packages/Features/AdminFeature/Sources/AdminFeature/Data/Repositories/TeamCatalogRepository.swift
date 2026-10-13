import Foundation

/// Concrete `TeamCatalogRepositoryProtocol` backed by the API via `TeamService`.
struct TeamCatalogRepository: TeamCatalogRepositoryProtocol {
    private let service: TeamServiceProtocol

    init(service: TeamServiceProtocol) {
        self.service = service
    }

    func fetchTeamCatalog() async throws -> [TeamVisualCatalogItem] {
        try await service.fetchTeamCatalog()
    }
}
