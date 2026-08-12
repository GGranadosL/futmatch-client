import Foundation

struct FetchAdminMatchesUseCase: FetchMatchesListUseCaseProtocol {
    private let repository: AdminMatchRepositoryProtocol

    init(repository: AdminMatchRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws -> [AdminMatch] {
        try await repository.fetchMatches()
    }
}
