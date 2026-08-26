import Foundation
import NetworkFramework

// MARK: - Protocol

protocol AccountServiceProtocol {
    func deleteAccount() async throws
}

// MARK: - Implementation

struct AccountService: AccountServiceProtocol {
    /// Canonical confirmation token expected by `DELETE /user/me`. The backend
    /// accepts both the English and Spanish token case-insensitively, so the
    /// client always sends this one regardless of the app language; the
    /// user-facing phrase is validated locally (see `DeleteAccountViewModel`).
    private static let confirmationToken = "DELETE_MY_ACCOUNT"

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func deleteAccount() async throws {
        struct DeleteAccountRequest: Encodable {
            let confirmation: String
        }
        let request = DeleteAccountRequest(confirmation: Self.confirmationToken)
        let _: EmptyResponse = try await apiClient.request(
            endpoint: AccountEndpoint.deleteAccount,
            body: request
        )
    }
}
