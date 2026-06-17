import Foundation

// MARK: - Protocol

public protocol ReplaceFieldImageUseCaseProtocol {
    /// Replaces an existing image. Returns the updated image UUID.
    func execute(fieldId: String, imageId: String, imageData: Data) async throws -> String
}

// MARK: - Implementation

public struct ReplaceFieldImageUseCase: ReplaceFieldImageUseCaseProtocol {
    private let repository: FieldRepositoryProtocol

    public init(repository: FieldRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(fieldId: String, imageId: String, imageData: Data) async throws -> String {
        try await repository.replaceFieldImage(fieldId: fieldId, imageId: imageId, imageData: imageData)
    }
}
