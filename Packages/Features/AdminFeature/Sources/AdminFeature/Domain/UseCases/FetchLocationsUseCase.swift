import Foundation

// MARK: - Fetch Locations UseCase

protocol FetchLocationsUseCaseProtocol {
    func execute() async throws -> [AdminLocation]
}

final class FetchLocationsUseCase: FetchLocationsUseCaseProtocol {
    private let repository: LocationRepositoryProtocol

    init(repository: LocationRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws -> [AdminLocation] {
        return try await repository.fetchLocations()
    }
}
