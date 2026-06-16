import Foundation

// MARK: - Fetch Locations UseCase

public protocol FetchLocationsUseCaseProtocol {
    /// Returns locally cached locations synchronously (empty if cache is cold).
    func executeCached() -> [AdminLocation]
    /// Fetches from the network, writes to cache, and returns the fresh list.
    func execute() async throws -> [AdminLocation]
}

final class FetchLocationsUseCase: FetchLocationsUseCaseProtocol {
    private let repository: LocationRepositoryProtocol

    init(repository: LocationRepositoryProtocol) {
        self.repository = repository
    }

    func executeCached() -> [AdminLocation] {
        repository.loadLocationsCache()
    }

    func execute() async throws -> [AdminLocation] {
        return try await repository.fetchLocations()
    }
}
