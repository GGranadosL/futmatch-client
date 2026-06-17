import Foundation

// MARK: - Protocol

public protocol CreateMatchUseCaseProtocol {
    func execute(_ params: CreateMatchParams) async throws -> AdminMatch
}

// MARK: - Implementation

struct CreateMatchUseCase: CreateMatchUseCaseProtocol {
    private let repository: AdminMatchRepositoryProtocol

    init(repository: AdminMatchRepositoryProtocol) {
        self.repository = repository
    }

    func execute(_ params: CreateMatchParams) async throws -> AdminMatch {
        try await repository.createMatch(params)
    }
}
