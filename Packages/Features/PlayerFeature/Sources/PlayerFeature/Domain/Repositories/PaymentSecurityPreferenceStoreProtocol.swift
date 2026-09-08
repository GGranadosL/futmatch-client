import Foundation

// MARK: - Payment Security Preference Store Protocol

/// Persists the "Seguridad en pagos" toggle from Settings — whether payment
/// and account deletion require a biometric/passcode prompt before they
/// proceed. Device-level security posture, not per-account state: it is
/// intentionally never cleared on logout (see `AuthorizeSensitiveActionUseCase`).
protocol PaymentSecurityPreferenceStoring {
    /// `true` when never explicitly set — the toggle defaults to enabled.
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool)
}
