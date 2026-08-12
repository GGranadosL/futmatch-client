import Foundation
import NetworkFramework

// MARK: - Protocol

protocol AccountServiceProtocol {
    func deleteAccount(password: String) async throws
}

// MARK: - Implementation

struct AccountService: AccountServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func deleteAccount(password: String) async throws {
        struct DeleteAccountRequest: Encodable {
            let password: String
            let confirmation: String
        }
        let request = DeleteAccountRequest(password: password, confirmation: "DELETE_MY_ACCOUNT")
        let _: EmptyResponse = try await apiClient.request(
            endpoint: AccountEndpoint.deleteAccount,
            body: request
        )
    }
}
