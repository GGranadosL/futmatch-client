import Foundation

// MARK: - Domain Model

public struct Country: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let name: String
    public let iso: String
    public let flag: String

    public var id: String { iso }

    public init(name: String, iso: String, flag: String) {
        self.name = name
        self.iso = iso
        self.flag = flag
    }

    /// Flag + name for display in pickers / dropdowns.
    public var displayName: String { "\(flag) \(name)" }
}

// MARK: - Remote Config payload shape

public struct CountryListPayload: Codable {
    public let version: Int
    public let countries: [Country]
}

// MARK: - Repository Protocol

public protocol CountryRepositoryProtocol: Sendable {
    func fetchCountries() async -> [Country]
}

// MARK: - Use Case Protocol

public protocol FetchCountriesUseCaseProtocol: Sendable {
    func execute() async -> [Country]
}

// MARK: - Use Case Implementation

public struct FetchCountriesUseCase: FetchCountriesUseCaseProtocol {
    private let repository: CountryRepositoryProtocol

    public init(repository: CountryRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async -> [Country] {
        await repository.fetchCountries()
    }
}

// MARK: - Fallback Repository (hardcoded — used in Previews & tests)

public struct FallbackCountryRepository: CountryRepositoryProtocol {
    public init() {}

    public func fetchCountries() async -> [Country] {
        Country.fallback
    }
}

// MARK: - Hardcoded fallback list
// Mirrors the `country_list` Firebase Remote Config key.
// Order: México first → North America → South America → Central America & Caribbean
//        → Europe → Asia → Middle East → Africa → Oceania

public extension Country {
    static let fallback: [Country] = [
        // ── North America ────────────────────────────────────────────────
        Country(name: "México",                iso: "MX", flag: "🇲🇽"),
        Country(name: "United States",         iso: "US", flag: "🇺🇸"),
        Country(name: "Canada",                iso: "CA", flag: "🇨🇦"),

        // ── South America ────────────────────────────────────────────────
        Country(name: "Colombia",              iso: "CO", flag: "🇨🇴"),
        Country(name: "Argentina",             iso: "AR", flag: "🇦🇷"),
        Country(name: "Peru",                  iso: "PE", flag: "🇵🇪"),
        Country(name: "Chile",                 iso: "CL", flag: "🇨🇱"),
        Country(name: "Brazil",                iso: "BR", flag: "🇧🇷"),
        Country(name: "Venezuela",             iso: "VE", flag: "🇻🇪"),
        Country(name: "Ecuador",               iso: "EC", flag: "🇪🇨"),
        Country(name: "Bolivia",               iso: "BO", flag: "🇧🇴"),
        Country(name: "Paraguay",              iso: "PY", flag: "🇵🇾"),
        Country(name: "Uruguay",               iso: "UY", flag: "🇺🇾"),

        // ── Central America & Caribbean ──────────────────────────────────
        Country(name: "Guatemala",             iso: "GT", flag: "🇬🇹"),
        Country(name: "Belize",                iso: "BZ", flag: "🇧🇿"),
        Country(name: "Honduras",              iso: "HN", flag: "🇭🇳"),
        Country(name: "El Salvador",           iso: "SV", flag: "🇸🇻"),
        Country(name: "Nicaragua",             iso: "NI", flag: "🇳🇮"),
        Country(name: "Costa Rica",            iso: "CR", flag: "🇨🇷"),
        Country(name: "Panama",                iso: "PA", flag: "🇵🇦"),
        Country(name: "Cuba",                  iso: "CU", flag: "🇨🇺"),
        Country(name: "Dominican Republic",    iso: "DO", flag: "🇩🇴"),

        // ── Europe ───────────────────────────────────────────────────────
        Country(name: "Spain",                 iso: "ES", flag: "🇪🇸"),
        Country(name: "United Kingdom",        iso: "GB", flag: "🇬🇧"),
        Country(name: "France",                iso: "FR", flag: "🇫🇷"),
        Country(name: "Germany",               iso: "DE", flag: "🇩🇪"),
        Country(name: "Italy",                 iso: "IT", flag: "🇮🇹"),
        Country(name: "Portugal",              iso: "PT", flag: "🇵🇹"),
        Country(name: "Netherlands",           iso: "NL", flag: "🇳🇱"),
        Country(name: "Belgium",               iso: "BE", flag: "🇧🇪"),
        Country(name: "Switzerland",           iso: "CH", flag: "🇨🇭"),
        Country(name: "Ireland",               iso: "IE", flag: "🇮🇪"),
        Country(name: "Sweden",                iso: "SE", flag: "🇸🇪"),
        Country(name: "Norway",                iso: "NO", flag: "🇳🇴"),
        Country(name: "Denmark",               iso: "DK", flag: "🇩🇰"),
        Country(name: "Poland",                iso: "PL", flag: "🇵🇱"),
        Country(name: "Austria",               iso: "AT", flag: "🇦🇹"),
        Country(name: "Czechia",               iso: "CZ", flag: "🇨🇿"),
        Country(name: "Romania",               iso: "RO", flag: "🇷🇴"),
        Country(name: "Türkiye",               iso: "TR", flag: "🇹🇷"),
        Country(name: "Russia",                iso: "RU", flag: "🇷🇺"),
        Country(name: "Ukraine",               iso: "UA", flag: "🇺🇦"),

        // ── Asia ─────────────────────────────────────────────────────────
        Country(name: "Japan",                 iso: "JP", flag: "🇯🇵"),
        Country(name: "China",                 iso: "CN", flag: "🇨🇳"),
        Country(name: "South Korea",           iso: "KR", flag: "🇰🇷"),
        Country(name: "India",                 iso: "IN", flag: "🇮🇳"),
        Country(name: "Philippines",           iso: "PH", flag: "🇵🇭"),
        Country(name: "Thailand",              iso: "TH", flag: "🇹🇭"),
        Country(name: "Vietnam",               iso: "VN", flag: "🇻🇳"),
        Country(name: "Indonesia",             iso: "ID", flag: "🇮🇩"),
        Country(name: "Malaysia",              iso: "MY", flag: "🇲🇾"),
        Country(name: "Singapore",             iso: "SG", flag: "🇸🇬"),

        // ── Middle East ──────────────────────────────────────────────────
        Country(name: "Israel",                iso: "IL", flag: "🇮🇱"),
        Country(name: "United Arab Emirates",  iso: "AE", flag: "🇦🇪"),
        Country(name: "Saudi Arabia",          iso: "SA", flag: "🇸🇦"),

        // ── Africa ───────────────────────────────────────────────────────
        Country(name: "Egypt",                 iso: "EG", flag: "🇪🇬"),
        Country(name: "Morocco",               iso: "MA", flag: "🇲🇦"),
        Country(name: "Nigeria",               iso: "NG", flag: "🇳🇬"),
        Country(name: "South Africa",          iso: "ZA", flag: "🇿🇦"),

        // ── Oceania ──────────────────────────────────────────────────────
        Country(name: "Australia",             iso: "AU", flag: "🇦🇺"),
        Country(name: "New Zealand",           iso: "NZ", flag: "🇳🇿"),
    ]
}
