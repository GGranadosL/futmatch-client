// MARK: - Update Admin Match Use Case Protocol

protocol UpdateAdminMatchUseCaseProtocol {
    func execute(_ params: UpdateMatchParams) async throws -> AdminMatch
}

// MARK: - Update Admin Match Use Case

struct UpdateAdminMatchUseCase: UpdateAdminMatchUseCaseProtocol {
    private let repository: AdminMatchRepositoryProtocol

    init(repository: AdminMatchRepositoryProtocol) {
        self.repository = repository
    }

    func execute(_ params: UpdateMatchParams) async throws -> AdminMatch {
        try await repository.updateMatch(params)
    }
}
