import Foundation

// MARK: - Result

enum PaymentPollResult {
    case success
    case failure
    case timeout
}

// MARK: - Protocol

protocol PollPaymentStatusUseCaseProtocol {
    /// Polls `GET /payment/poll/{matchId}` every `intervalSeconds` until
    /// the backend reports a terminal state (`isFinal == true`) or `maxAttempts`
    /// is exhausted.
    ///
    /// - Returns: `.success` when `isFinal && isSuccess`,
    ///            `.failure` when `isFinal && !isSuccess`,
    ///            `.timeout` when max attempts are reached without a terminal state.
    func execute(
        matchId: String,
        intervalSeconds: Double,
        maxAttempts: Int
    ) async -> PaymentPollResult
}

extension PollPaymentStatusUseCaseProtocol {
    /// Convenience overload with sensible defaults (~26 s total polling window:
    /// 1.5 s initial delay + 9 × 2.5 s). After that we fall back to the status endpoint.
    func execute(matchId: String) async -> PaymentPollResult {
        await execute(matchId: matchId, intervalSeconds: 2.5, maxAttempts: 10)
    }
}

// MARK: - Implementation

struct PollPaymentStatusUseCase: PollPaymentStatusUseCaseProtocol {
    private let paymentService: PaymentServiceProtocol

    init(paymentService: PaymentServiceProtocol) {
        self.paymentService = paymentService
    }

    func execute(
        matchId: String,
        intervalSeconds: Double,
        maxAttempts: Int       // ~60 s total
    ) async -> PaymentPollResult {
        for attempt in 1...maxAttempts {
            // Wait before every attempt (including the first one) so Stripe's
            // webhook has time to reach the backend before we hit the endpoint.
            if attempt > 1 {
                try? await Task.sleep(for: .seconds(intervalSeconds))
            } else {
                // Small initial delay to give the backend time to process the payment.
                try? await Task.sleep(for: .seconds(1.5))
            }

            guard !Task.isCancelled else { return .timeout }

            do {
                guard let poll = try await paymentService.pollPaymentStatus(matchId: matchId) else {
                    // Backend has no active payment yet — keep polling.
                    continue
                }

                if poll.isFinal {
                    return poll.isSuccess ? .success : .failure
                }
                // Not final yet — continue polling.
            } catch {
                // Network hiccup or backend 500 — keep trying unless cancelled.
                guard !Task.isCancelled else { return .timeout }
            }
        }

        // Polling exhausted its retries (e.g. the poll endpoint kept failing).
        // Fall back to the full status endpoint as a safety net before giving up.
        return await fallbackToStatus(matchId: matchId)
    }

    /// Last-resort confirmation via `GET /payment/status/{matchId}`.
    /// Maps the backend-internal status to a poll result.
    private func fallbackToStatus(matchId: String) async -> PaymentPollResult {
        guard !Task.isCancelled else { return .timeout }
        do {
            guard let status = try await paymentService.fetchPaymentStatus(matchId: matchId) else {
                return .timeout
            }
            switch status.status.uppercased() {
            case "SUCCEEDED", "AUTHORIZED":
                // Funds captured or authorized — the user's spot is secured.
                return .success
            case "CANCELED", "CANCELLED", "FAILED":
                return .failure
            default:
                // CREATED or unknown — still not confirmed.
                return .timeout
            }
        } catch {
            return .timeout
        }
    }
}
