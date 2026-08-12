import Foundation

public protocol DeleteAccountUseCaseProtocol {
    func execute(password: String) async throws
}

public struct DeleteAccountUseCase: DeleteAccountUseCaseProtocol {
    private let repository: AccountRepositoryProtocol

    public init(repository: AccountRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(password: String) async throws {
        try await repository.deleteAccount(password: password)
    }
}
