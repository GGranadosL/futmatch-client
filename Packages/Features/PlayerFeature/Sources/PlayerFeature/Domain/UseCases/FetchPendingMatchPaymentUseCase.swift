import Foundation

// MARK: - Result Type

/// Recovery outcome of attempting to rehidrate payment data from the backend
/// when the local cache is missing but a RESERVED reservation exists.
enum PendingPaymentRecovery: Equatable {
    /// Payment data was recovered and Stripe PaymentSheet can be opened.
    case recovered(JoinMatchData)
    /// Payment cannot be recovered (409, 404, or incomplete data). Message is
    /// the backend's user-facing error or a fallback, for the dialog.
    case notRecoverable(message: String?)
    /// Backend temporarily unavailable (503). User can retry later.
    case retryLater(message: String?)
    /// Demo mode, network cancellation, or other non-client-facing issue.
    /// No dialog should fire.
    case unavailable
}

// MARK: - Protocol

protocol FetchPendingMatchPaymentUseCaseProtocol {
    /// Attempts to recover in-flight payment data from the backend when
    /// a RESERVED reservation exists but the local Keychain cache is empty.
    func execute(matchId: String) async -> PendingPaymentRecovery
}

// MARK: - Implementation

struct FetchPendingMatchPaymentUseCase: FetchPendingMatchPaymentUseCaseProtocol {
    private let paymentService: PaymentServiceProtocol
    private let isDemoMode: Bool

    init(
        paymentService: PaymentServiceProtocol,
        isDemoMode: Bool
    ) {
        self.paymentService = paymentService
        self.isDemoMode = isDemoMode
    }

    func execute(matchId: String) async -> PendingPaymentRecovery {
        guard !isDemoMode else { return .unavailable }

        do {
            guard let data = try await paymentService.fetchPendingMatchPayment(matchId: matchId) else {
                // Backend has no active payment for the user in this match.
                return .notRecoverable(message: nil)
            }

            // Validate that all four required fields for PaymentSheet are present.
            guard let clientSecret = data.clientSecret,
                  !clientSecret.isEmpty,
                  let publishableKey = data.publishableKey,
                  !publishableKey.isEmpty,
                  let customer = data.customer,
                  !customer.isEmpty,
                  let customerSessionClientSecret = data.customerSessionClientSecret,
                  !customerSessionClientSecret.isEmpty else {
                // Incomplete recovery — Stripe PaymentSheet won't work.
                return .notRecoverable(message: nil)
            }

            return .recovered(data)
        } catch {
            guard !error.isCancellation else { return .unavailable }

            // Branch by errorCode first, then statusCode as fallback.
            let errorCode = error.apiErrorCode ?? ""
            let statusCode = error.apiStatusCode ?? 0

            if errorCode == "PAYMENT_PENDING_NOT_RECOVERABLE" || statusCode == 409 || statusCode == 404 {
                return .notRecoverable(message: error.apiErrorMessage)
            }

            if errorCode == "PAYMENT_FAILED" || statusCode == 503 {
                return .retryLater(message: error.apiErrorMessage)
            }

            // Everything else (network errors, 5xx, etc.) is silently unavailable.
            return .unavailable
        }
    }
}
