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

    public var centerLatitude: Double {
        switch self {
        case .cdmx:  return 19.4326
        case .gdl:   return 20.6597
        case .mty:   return 25.6866
        case .qro:   return 20.5888
        case .pue:   return 19.0413
        case .tij:   return 32.5027
        case .leon:  return 21.1167
        case .cjs:   return 28.6353
        case .tx:    return 31.0
        }
    }

    public var centerLongitude: Double {
        switch self {
        case .cdmx:  return -99.1332
        case .gdl:   return -103.3496
        case .mty:   return -100.3161
        case .qro:   return -100.3899
        case .pue:   return -98.2062
        case .tij:   return -117.0037
        case .leon:  return -101.6833
        case .cjs:   return -106.0889
        case .tx:    return -100.0
        }
    }

    /// Lat/lon delta for the map region when panning to this city.
    public var mapSpanDelta: Double {
        switch self {
        case .cdmx:  return 0.40
        case .tx:    return 8.0
        default:     return 0.18
        }
    }

    /// Approximate bounding box of the metropolitan area.
    /// Used to reject pins placed outside the selected city.
    public var boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        switch self {
        case .cdmx:  return (19.00, 19.95, -99.50, -98.85)
        case .gdl:   return (20.50, 20.85, -103.60, -103.10)
        case .mty:   return (25.40, 25.90, -100.65, -100.05)
        case .qro:   return (20.45, 20.75, -100.50, -100.20)
        case .pue:   return (18.85, 19.20, -98.35, -97.95)
        case .tij:   return (32.35, 32.65, -117.20, -116.80)
        case .leon:  return (20.90, 21.30, -101.90, -101.45)
        case .cjs:   return (28.45, 28.80, -106.35, -105.90)
        case .tx:    return (25.84, 36.50, -106.65,  -93.51)
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
