import Foundation

// MARK: - Create Location UseCase

protocol CreateLocationUseCaseProtocol {
    /// Creates a location on the backend and persists it to the local cache.
    func execute(request: CreateLocationRequest) async throws -> AdminLocation
}

final class CreateLocationUseCase: CreateLocationUseCaseProtocol {
    private let repository: LocationRepositoryProtocol

    init(repository: LocationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: CreateLocationRequest) async throws -> AdminLocation {
        try await repository.createLocation(request: request)
    }
}
