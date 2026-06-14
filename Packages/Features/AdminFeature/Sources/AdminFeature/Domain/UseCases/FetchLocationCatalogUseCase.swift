import Foundation

// MARK: - Fetch Location Catalog Use Case

public protocol FetchLocationCatalogUseCaseProtocol {
    func execute() async -> [AdminLocationCountry]
}

public struct FetchLocationCatalogUseCase: FetchLocationCatalogUseCaseProtocol {
    private let repository: LocationCatalogRepositoryProtocol

    public init(repository: LocationCatalogRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async -> [AdminLocationCountry] {
        let catalog = await repository.fetchCatalog()
        return catalog.isEmpty ? .fallback : catalog
    }
}
