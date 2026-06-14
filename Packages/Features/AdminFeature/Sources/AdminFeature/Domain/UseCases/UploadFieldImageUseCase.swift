import Foundation

// MARK: - Protocol

public protocol UploadFieldImageUseCaseProtocol {
    /// Uploads a new image at `position`. Returns the new image UUID.
    func execute(fieldId: String, position: Int, imageData: Data) async throws -> String
}

// MARK: - Implementation

public struct UploadFieldImageUseCase: UploadFieldImageUseCaseProtocol {
    private let repository: FieldRepositoryProtocol

    public init(repository: FieldRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(fieldId: String, position: Int, imageData: Data) async throws -> String {
        try await repository.uploadFieldImage(fieldId: fieldId, position: position, imageData: imageData)
    }
}
