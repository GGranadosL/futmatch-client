import Foundation

public protocol DeleteAccountUseCaseProtocol {
    func execute() async throws
}

public struct DeleteAccountUseCase: DeleteAccountUseCaseProtocol {
    private let repository: AccountRepositoryProtocol

    public init(repository: AccountRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.deleteAccount()
    }
}
