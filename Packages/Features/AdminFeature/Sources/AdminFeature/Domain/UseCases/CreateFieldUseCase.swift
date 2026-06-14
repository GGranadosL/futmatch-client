import Foundation

// MARK: - Protocol

public protocol CreateFieldUseCaseProtocol {
    func execute(_ params: CreateFieldParams) async throws -> Field
}

// MARK: - Implementation

public struct CreateFieldUseCase: CreateFieldUseCaseProtocol {
    private let repository: FieldRepositoryProtocol

    public init(repository: FieldRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(_ params: CreateFieldParams) async throws -> Field {
        try await repository.createField(params)
    }
}
