import Foundation

public protocol DeleteFieldUseCaseProtocol {
    func execute(fieldId: String) async throws
}

public struct DeleteFieldUseCase: DeleteFieldUseCaseProtocol {
    private let repository: FieldRepositoryProtocol

    public init(repository: FieldRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(fieldId: String) async throws {
        try await repository.deleteField(fieldId: fieldId)
    }
}
