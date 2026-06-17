import Foundation

// MARK: - Protocol

public protocol FetchAdminMatchesUseCaseProtocol {
    func execute() async throws -> [AdminMatch]
}

// MARK: - Implementation

struct FetchAdminMatchesUseCase: FetchAdminMatchesUseCaseProtocol {
    private let repository: AdminMatchRepositoryProtocol

    init(repository: AdminMatchRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws -> [AdminMatch] {
        try await repository.fetchMatches()
    }
}
