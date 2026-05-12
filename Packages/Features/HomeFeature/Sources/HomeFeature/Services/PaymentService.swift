import Foundation
import NetworkFramework

// MARK: - Protocol

protocol PaymentServiceProtocol {
    func fetchCustomerSession() async throws -> CustomerSessionData
    func createSetupIntent() async throws -> SetupIntentData
    func fetchPaymentHistory() async throws -> [PaymentHistoryItem]
}

// MARK: - Implementation

final class PaymentService: PaymentServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchCustomerSession() async throws -> CustomerSessionData {
        let response: CustomerSessionResponse = try await apiClient.request(
            endpoint: PaymentEndpoint.customerSheetInit
        )
        return response.data
    }

    func createSetupIntent() async throws -> SetupIntentData {
        let response: SetupIntentResponse = try await apiClient.request(
            endpoint: PaymentEndpoint.setupIntent
        )
        return response.data
    }

    func fetchPaymentHistory() async throws -> [PaymentHistoryItem] {
        let response: PaymentHistoryResponse = try await apiClient.request(
            endpoint: PaymentEndpoint.paymentHistory
        )
        return response.data
    }
}
