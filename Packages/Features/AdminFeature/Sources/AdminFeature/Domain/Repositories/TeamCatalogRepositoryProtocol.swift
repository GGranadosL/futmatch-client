import Foundation

/// Remote source of the team identity catalog.
public protocol TeamCatalogRepositoryProtocol {
    func fetchTeamCatalog() async throws -> [TeamVisualCatalogItem]
}

/// Local persistence of the team identity catalog.
public protocol TeamCatalogCacheRepositoryProtocol {
    func saveTeams(_ items: [TeamVisualCatalogItem]) throws
    func loadTeams() -> [TeamVisualCatalogItem]
    func clearTeams() throws
}
