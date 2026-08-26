import Foundation

/// Concrete `AccountRepositoryProtocol` backed by the API via `AccountService`.
struct AccountRepository: AccountRepositoryProtocol {
    private let service: AccountServiceProtocol

    init(service: AccountServiceProtocol) {
        self.service = service
    }

    func deleteAccount() async throws {
        try await service.deleteAccount()
    }
}
