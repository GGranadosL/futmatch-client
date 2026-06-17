import Foundation

// MARK: - Protocol

public protocol FetchAdminFieldsUseCaseProtocol {
    func execute() async throws -> [AdminFieldItem]
}

// MARK: - Implementation

public struct FetchAdminFieldsUseCase: FetchAdminFieldsUseCaseProtocol {
    private let repository: AdminFieldsRepositoryProtocol

    public init(repository: AdminFieldsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [AdminFieldItem] {
        try await repository.fetchFields()
    }
}
