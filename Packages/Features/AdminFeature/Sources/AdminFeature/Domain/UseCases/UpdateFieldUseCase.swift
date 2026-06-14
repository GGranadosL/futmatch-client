import Foundation

public protocol UpdateFieldUseCaseProtocol {
    func execute(fieldId: String, _ params: CreateFieldParams) async throws
}

public struct UpdateFieldUseCase: UpdateFieldUseCaseProtocol {
    private let repository: FieldRepositoryProtocol

    public init(repository: FieldRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(fieldId: String, _ params: CreateFieldParams) async throws {
        try await repository.updateField(fieldId: fieldId, params)
    }
}
