import Foundation

// MARK: - Protocol

public protocol DeleteFieldImageUseCaseProtocol {
    /// Deletes an existing image.
    func execute(fieldId: String, imageId: String) async throws
}

// MARK: - Implementation

public struct DeleteFieldImageUseCase: DeleteFieldImageUseCaseProtocol {
    private let repository: FieldRepositoryProtocol

    public init(repository: FieldRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(fieldId: String, imageId: String) async throws {
        try await repository.deleteFieldImage(fieldId: fieldId, imageId: imageId)
    }
}
