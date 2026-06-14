import Foundation

public protocol FetchFieldIdNamesUseCaseProtocol {
    func execute() async throws -> [FieldIdName]
}

public struct FetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol {
    private let repository: FieldRepositoryProtocol

    public init(repository: FieldRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [FieldIdName] {
        try await repository.fetchFieldIdNames()
    }
}
