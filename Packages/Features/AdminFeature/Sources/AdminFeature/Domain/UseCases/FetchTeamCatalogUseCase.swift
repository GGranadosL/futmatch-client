import Foundation

public protocol FetchTeamCatalogUseCaseProtocol {
    /// Returns the local catalog when present; otherwise (or when `forceRefresh`)
    /// requests it from the network and replaces the local copy. A failed
    /// request throws without touching the stored catalog.
    func execute(forceRefresh: Bool) async throws -> [TeamVisualCatalogItem]
}

public struct FetchTeamCatalogUseCase: FetchTeamCatalogUseCaseProtocol {
    private let repository: TeamCatalogRepositoryProtocol
    private let cache: TeamCatalogCacheRepositoryProtocol

    public init(repository: TeamCatalogRepositoryProtocol, cache: TeamCatalogCacheRepositoryProtocol) {
        self.repository = repository
        self.cache = cache
    }

    public func execute(forceRefresh: Bool) async throws -> [TeamVisualCatalogItem] {
        if !forceRefresh {
            let cached = cache.loadTeams()
            if !cached.isEmpty { return cached }
        }
        let fresh = try await repository.fetchTeamCatalog()
        try? cache.saveTeams(fresh)
        return fresh
    }
}
