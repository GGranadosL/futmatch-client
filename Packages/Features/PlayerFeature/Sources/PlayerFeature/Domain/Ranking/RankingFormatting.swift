import Foundation

enum RankingFormatting {
    /// The app's language (what the string catalogs resolve to), keeping the device
    /// region when it matches so date order still follows the user's settings.
    static var appLocale: Locale {
        let language = Bundle.module.preferredLocalizations.first ?? "en"
        if Locale.current.language.languageCode?.identifier == language {
            return .current
        }
        return Locale(identifier: language)
    }

    /// "noviembre 2026". The season is a year/month identity: formatting it in any
    /// zone must not shift it, so the date is built and read in UTC.
    static func month(_ season: RankingSeason, locale: Locale = appLocale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC") ?? .current
        calendar.timeZone = utc
        guard let date = calendar.date(from: DateComponents(year: season.year, month: season.month, day: 1)) else {
            return "\(season.month)/\(season.year)"
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = utc
        formatter.setLocalizedDateFormatFromTemplate("LLLLyyyy")
        return formatter.string(from: date)
    }

    /// `calculatedAt` (epoch ms) as a short date and time in the device's zone.
    static func updatedAt(
        _ milliseconds: Int64,
        locale: Locale = appLocale,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: Double(milliseconds) / 1000))
    }

    /// ISO-2 country code → flag emoji. `nil` for anything that isn't two letters.
    static func flag(for country: String?) -> String? {
        guard let code = country?.uppercased(),
              code.count == 2,
              code.unicodeScalars.allSatisfy({ (65...90).contains($0.value) })
        else { return nil }
        return code.unicodeScalars.compactMap { Unicode.Scalar($0.value + 127397) }.map(String.init).joined()
    }
}
