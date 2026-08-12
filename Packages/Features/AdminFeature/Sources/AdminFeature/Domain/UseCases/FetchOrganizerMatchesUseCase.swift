import Foundation

struct FetchOrganizerMatchesUseCase: FetchMatchesListUseCaseProtocol {
    private let repository: OrganizerMatchRepositoryProtocol

    init(repository: OrganizerMatchRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws -> [AdminMatch] {
        try await repository.fetchMatches()
    }
}
