import Foundation

/// The backend sends admins the full email and phone. They are masked here, before
/// they reach any view model, so full values are never displayed or logged.
public enum ContactMasking {
    /// "ana.lopez@example.com" → "a***@example.com". `nil` for missing/invalid values.
    public static func maskEmail(_ email: String?) -> String? {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else { return nil }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let first = parts[0].first,
              !parts[1].isEmpty,
              parts[1].contains(".")
        else { return nil }
        return "\(first)***@\(parts[1])"
    }

    /// "+525512345678" → "***78". `nil` when there aren't enough digits to keep two
    /// and still hide the rest.
    public static func maskPhone(_ phone: String?) -> String? {
        guard let phone else { return nil }
        let digits = phone.filter(\.isNumber)
        guard digits.count >= 6 else { return nil }
        return "***\(digits.suffix(2))"
    }
}
