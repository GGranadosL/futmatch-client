import Foundation

// MARK: - Location Catalog Repository Protocol

/// Provides the catalog of countries/cities available when creating a location.
public protocol LocationCatalogRepositoryProtocol {
    /// Never throws — implementations fall back to the hardcoded catalog.
    func fetchCatalog() async -> [AdminLocationCountry]
}
