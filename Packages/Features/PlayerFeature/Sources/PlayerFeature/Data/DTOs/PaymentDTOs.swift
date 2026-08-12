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

// MARK: - Pending Match Payment (GET /payment/matches/{matchId}/pending)

/// Recovers the Stripe inputs of an in-flight payment when the user already holds a
/// RESERVED spot in the match. Used only when the locally cached payment data is
/// missing — another device, a reinstall, or a lost Keychain entry.
struct PendingMatchPaymentResponse: Decodable {
    let data: PendingMatchPaymentData
}

struct PendingMatchPaymentData: Decodable {
    let clientSecret: String?
    let paymentId: String
    let provider: String
    let amountInCents: Int
    let currency: String
    let customer: String?
    let customerSessionClientSecret: String?
    let publishableKey: String?
    /// REMAINING reservation time, not a fresh window. Never used to seed the
    /// countdown — that comes from Firestore's `reservationExpiresAt`.
    let reservationTtlMs: Int
    let existingPaymentStatus: String?
}

extension PendingMatchPaymentData {
    /// Maps onto the join payload so the existing PaymentSheet and local-persistence
    /// paths are reused unchanged. `reusedExistingPayment` is false: this is a payment
    /// still waiting to be made, not one the backend already settled.
    func toJoinMatchData() -> JoinMatchData {
        JoinMatchData(
            clientSecret: clientSecret,
            paymentId: paymentId,
            provider: provider,
            amountInCents: amountInCents,
            currency: currency,
            customer: customer,
            customerSessionClientSecret: customerSessionClientSecret,
            publishableKey: publishableKey,
            reservationTtlMs: reservationTtlMs,
            reusedExistingPayment: false,
            existingPaymentStatus: existingPaymentStatus
        )
    }
}
