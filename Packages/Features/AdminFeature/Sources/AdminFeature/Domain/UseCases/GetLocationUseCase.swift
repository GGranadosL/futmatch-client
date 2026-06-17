import Foundation

protocol GetLocationUseCaseProtocol {
    func execute(id: String) async throws -> AdminLocation
}

final class GetLocationUseCase: GetLocationUseCaseProtocol {
    private let repository: LocationRepositoryProtocol

    init(repository: LocationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(id: String) async throws -> AdminLocation {
        try await repository.getLocation(id: id)
    }
}
