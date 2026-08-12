import Foundation

/// User-facing outcome of attempting to recover pending payment data when
/// the local cache is missing but a RESERVED reservation exists.
enum PendingPaymentIssue: Equatable {
    /// Payment cannot be recovered (409, 404, or incomplete data).
    /// Message is the backend's error or a localized fallback.
    case notRecoverable(String)
    /// Backend temporarily unavailable (503). User can retry.
    case retryLater(String)
}
