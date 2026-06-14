import Foundation

protocol UpdateLocationUseCaseProtocol {
    func execute(request: UpdateLocationRequest) async throws -> AdminLocation
}

final class UpdateLocationUseCase: UpdateLocationUseCaseProtocol {
    private let repository: LocationRepositoryProtocol

    init(repository: LocationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: UpdateLocationRequest) async throws -> AdminLocation {
        try await repository.updateLocation(request: request)
    }
}
