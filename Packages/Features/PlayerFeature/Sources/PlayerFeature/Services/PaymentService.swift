import Foundation
import NetworkFramework

// MARK: - Protocol

protocol PaymentServiceProtocol {
    func fetchCustomerSession() async throws -> CustomerSessionData
    func createSetupIntent() async throws -> SetupIntentData
    func fetchPaymentMethods() async throws -> [PaymentMethodItem]
    func fetchPaymentHistory() async throws -> [PaymentHistoryItem]
    /// Returns nil when the backend has no active payment for the user in that match.
    func pollPaymentStatus(matchId: String) async throws -> PaymentPollData?
    /// Fallback to the full status endpoint. Returns nil when no active payment exists.
    func fetchPaymentStatus(matchId: String) async throws -> PaymentStatusData?
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

    func fetchPaymentMethods() async throws -> [PaymentMethodItem] {
        let response: PaymentMethodsResponse = try await apiClient.request(
            endpoint: PaymentEndpoint.paymentMethods
        )
        return response.data
    }

    func fetchPaymentHistory() async throws -> [PaymentHistoryItem] {
        let response: PaymentHistoryResponse = try await apiClient.request(
            endpoint: PaymentEndpoint.paymentHistory
        )
        return response.data
    }

    func pollPaymentStatus(matchId: String) async throws -> PaymentPollData? {
        let response: PaymentPollResponse = try await apiClient.request(
            endpoint: PaymentEndpoint.pollPayment(matchId: matchId)
        )
        return response.data
    }

    func fetchPaymentStatus(matchId: String) async throws -> PaymentStatusData? {
        let response: PaymentStatusResponse = try await apiClient.request(
            endpoint: PaymentEndpoint.paymentStatus(matchId: matchId)
        )
        return response.data
    }
}
