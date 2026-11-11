import Foundation

/// Formatting rules for the admin users screens, kept out of the views so they can be tested.
public struct AdminUsersFormatting {
    private let locale: Locale
    private let timeZone: TimeZone

    public init(locale: Locale = .current, timeZone: TimeZone = .current) {
        self.locale = locale
        self.timeZone = timeZone
    }

    /// "$180.00 MXN". Minor units follow the currency (2 for MXN/USD, 0 for JPY…);
    /// the code is always appended so different currencies are never confused.
    public func money(amountInCents: Int64, currency: String) -> String {
        let code = currency.uppercased()
        guard code.count == 3 else {
            return String(format: "%.2f", Double(amountInCents) / 100)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        // Use the symbol only when it's unambiguous ("$" for MXN in es-MX); the code
        // after the amount names the currency either way.
        formatter.currencySymbol = formatter.currencySymbol.count <= 2 ? formatter.currencySymbol : "$"
        let digits = formatter.maximumFractionDigits
        let divisor = pow(10, Double(digits))
        let value = NSDecimalNumber(value: Double(amountInCents) / divisor)
        let formatted = formatter.string(from: value) ?? "\(value)"
        return "\(formatted) \(code)"
    }

    /// "31 oct 2026 13:00".
    public func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy HH:mm")
        return formatter.string(from: date)
    }

    /// "1 sept 2026".
    public func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return formatter.string(from: date)
    }

    /// Case- and accent-insensitive name match ("jose" finds "José").
    public static func nameMatches(_ name: String, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
