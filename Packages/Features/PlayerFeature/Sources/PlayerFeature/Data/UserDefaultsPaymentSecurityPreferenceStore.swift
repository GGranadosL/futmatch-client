import Foundation

// MARK: - UserDefaults Payment Security Preference Store

/// `UserDefaults`-backed store for the "Seguridad en pagos" toggle.
final class UserDefaultsPaymentSecurityPreferenceStore: PaymentSecurityPreferenceStoring {
    private static let storageKey = "paymentSecurity.enabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        // `bool(forKey:)` returns false for a missing key, which would ship
        // the toggle OFF on first run. Reading the boxed value and defaulting
        // only when it's genuinely absent gets "on by default" right.
        (defaults.object(forKey: Self.storageKey) as? Bool) ?? true
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.storageKey)
    }
}
