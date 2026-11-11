import Foundation

/// Turns an ISO 3166-1 alpha-2 code ("MX") into its flag emoji ("🇲🇽").
public enum CountryFlag {
    /// `nil` when the code is missing or isn't two ASCII letters.
    public static func emoji(for isoCode: String?) -> String? {
        guard let code = isoCode?.trimmingCharacters(in: .whitespaces).uppercased(),
              code.count == 2,
              code.unicodeScalars.allSatisfy({ ("A"..."Z").contains($0) })
        else { return nil }
        let base: UInt32 = 127_397 // regional indicator "A" minus ASCII "A"
        var flag = ""
        for scalar in code.unicodeScalars {
            guard let indicator = UnicodeScalar(base + scalar.value) else { return nil }
            flag.unicodeScalars.append(indicator)
        }
        return flag
    }
}
