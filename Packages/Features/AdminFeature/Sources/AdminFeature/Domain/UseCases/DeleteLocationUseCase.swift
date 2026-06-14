import Foundation

protocol DeleteLocationUseCaseProtocol {
    func execute(id: String) async throws
}

final class DeleteLocationUseCase: DeleteLocationUseCaseProtocol {
    private let repository: LocationRepositoryProtocol

    init(repository: LocationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(id: String) async throws {
        try await repository.deleteLocation(id: id)
    }
}
