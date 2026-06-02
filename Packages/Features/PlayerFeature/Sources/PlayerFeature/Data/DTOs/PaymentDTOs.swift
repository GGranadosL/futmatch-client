import Foundation

// MARK: - Customer Session

struct CustomerSessionData: Decodable {
    let customerId: String
    let customerSessionClientSecret: String
    let publishableKey: String
}

struct CustomerSessionResponse: Decodable {
    let data: CustomerSessionData
}

// MARK: - Setup Intent

struct SetupIntentData: Decodable {
    let customerId: String
    let clientSecret: String
    let publishableKey: String
}

struct SetupIntentResponse: Decodable {
    let data: SetupIntentData
}

// MARK: - Payment Method

struct PaymentMethodItem: Decodable, Identifiable {
    let id: String
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
}

struct PaymentMethodsResponse: Decodable {
    let data: [PaymentMethodItem]
}

// MARK: - Payment History

struct PaymentHistoryItem: Decodable, Identifiable {
    let id: String
    let amount: Int
    let currency: String
    let status: String
    let createdAt: Int64
    let paidAt: Int64?
    let paymentMethod: PaymentMethodInfo?
    let refund: RefundInfo?
}

struct PaymentMethodInfo: Decodable {
    let last4: String
    let brand: String
}

struct RefundInfo: Decodable {
    let id: String
    let amount: Int
    let status: String
    let createdAt: Int64
    let refundedAt: Int64?
}

struct PaymentHistoryResponse: Decodable {
    let data: [PaymentHistoryItem]
}

// MARK: - Payment Poll (GET /payment/poll/{matchId})

/// Lightweight response from the polling endpoint.
/// `data` is null when there is no active payment for the user in that match.
struct PaymentPollResponse: Decodable {
    let data: PaymentPollData?
}

struct PaymentPollData: Decodable {
    /// Backend-internal payment status (CREATED, AUTHORIZED, SUCCEEDED, CANCELED, FAILED, REFUNDED).
    let status: String
    /// True when the payment has reached a terminal state (no more polling needed).
    let isFinal: Bool
    /// True when the payment was successful (authorized or captured).
    let isSuccess: Bool
}

// MARK: - Payment Status (GET /payment/status/{matchId})

/// Fallback endpoint used when polling exhausts its retries. Returns the full
/// payment record (including the backend-internal `status`).
/// `data` is null when there is no active payment for the user in that match.
struct PaymentStatusResponse: Decodable {
    let data: PaymentStatusData?
}

struct PaymentStatusData: Decodable {
    let paymentId: String?
    let providerPaymentId: String?
    /// Backend-internal payment status (CREATED, AUTHORIZED, SUCCEEDED, CANCELED).
    let status: String
    let provider: String?
}
