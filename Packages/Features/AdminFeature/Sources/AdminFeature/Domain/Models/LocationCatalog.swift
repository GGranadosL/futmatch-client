import Foundation

// MARK: - Location Catalog Models

/// A city available for creating locations, as exposed by the catalog.
public struct AdminLocationCity: Codable, Equatable {
    public let code: String
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

/// A country (with its cities) available for creating locations.
public struct AdminLocationCountry: Codable, Equatable {
    public let code: String
    public let name: String
    public let cities: [AdminLocationCity]

    public init(code: String, name: String, cities: [AdminLocationCity]) {
        self.code = code
        self.name = name
        self.cities = cities
    }
}

// MARK: - Supported Locations (hardcoded fallback)

/// Countries currently supported for location creation. Single source of truth
/// for the hardcoded fallback used until Remote Config delivers the catalog.
public enum LocationCountry: String, CaseIterable {
    case mexico = "MX"
    case unitedStates = "US"

    public var displayName: String {
        switch self {
        case .mexico: return "México"
        case .unitedStates: return "Estados Unidos"
        }
    }

    public var englishName: String {
        switch self {
        case .mexico: return "Mexico"
        case .unitedStates: return "United States"
        }
    }

    public var cities: [LocationCity] {
        switch self {
        case .mexico: return [.cdmx, .gdl, .mty, .qro, .pue, .tij, .leon, .cjs]
        case .unitedStates: return [.tx]
        }
    }
}

/// Cities currently supported for location creation.
public enum LocationCity: String, CaseIterable {
    case cdmx = "MX_CDMX"
    case gdl = "MX_GDL"
    case mty = "MX_MTY"
    case qro = "MX_QRO"
    case pue = "MX_PUE"
    case tij = "MX_TIJ"
    case leon = "MX_LEON"
    case cjs = "MX_CJS"
    case tx = "US_TX"

    public var displayName: String {
        switch self {
        case .cdmx: return "Ciudad de México"
        case .gdl: return "Guadalajara"
        case .mty: return "Monterrey"
        case .qro: return "Querétaro"
        case .pue: return "Puebla"
        case .tij: return "Tijuana"
        case .leon: return "León"
        case .cjs: return "Chihuahua"
        case .tx: return "Texas"
        }
    }

    public var englishName: String {
        switch self {
        case .cdmx: return "Mexico City"
        case .gdl: return "Guadalajara"
        case .mty: return "Monterrey"
        case .qro: return "Querétaro"
        case .pue: return "Puebla"
        case .tij: return "Tijuana"
        case .leon: return "León"
        case .cjs: return "Chihuahua"
        case .tx: return "Texas"
        }
    }
}

public extension Array where Element == AdminLocationCountry {
    /// Catalog built from the supported-locations enums — used when Remote
    /// Config has no value yet (first launch offline) or fails to parse.
    static var fallback: [AdminLocationCountry] {
        LocationCountry.allCases.map { country in
            AdminLocationCountry(
                code: country.rawValue,
                name: country.displayName,
                cities: country.cities.map { AdminLocationCity(code: $0.rawValue, name: $0.displayName) }
            )
        }
    }
}

// MARK: - Location Localizer

/// Translates country/city codes to localized display names based on the current locale.
public struct LocationLocalizer {
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public func countryName(for code: String) -> String {
        if let country = LocationCountry(rawValue: code) {
            return isSpanish ? country.displayName : country.englishName
        }
        return code
    }

    public func cityName(for code: String) -> String {
        if let city = LocationCity(rawValue: code) {
            return isSpanish ? city.displayName : city.englishName
        }
        return code
    }

    private var isSpanish: Bool {
        locale.languageCode?.hasPrefix("es") ?? false
    }
}
