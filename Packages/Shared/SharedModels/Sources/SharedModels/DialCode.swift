import Foundation

// MARK: - Domain Model

public struct DialCode: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let country: String
    public let iso: String
    public let dialCode: String
    public let flag: String

    public var id: String { iso }

    public init(country: String, iso: String, dialCode: String, flag: String) {
        self.country = country
        self.iso = iso
        self.dialCode = dialCode
        self.flag = flag
    }

    /// Flag + dial code for the narrow phone-prefix picker: "🇲🇽 +52"
    public var displayName: String { "\(flag) \(dialCode)" }
}

// MARK: - Remote Config payload shape

public struct DialCodeListPayload: Codable {
    public let version: Int
    public let dialCodes: [DialCode]
}

// MARK: - Repository Protocol

public protocol DialCodeRepositoryProtocol: Sendable {
    func fetchDialCodes() async -> [DialCode]
}

// MARK: - Use Case Protocol

public protocol FetchDialCodesUseCaseProtocol: Sendable {
    func execute() async -> [DialCode]
}

// MARK: - Use Case Implementation

public struct FetchDialCodesUseCase: FetchDialCodesUseCaseProtocol {
    private let repository: DialCodeRepositoryProtocol

    public init(repository: DialCodeRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async -> [DialCode] {
        await repository.fetchDialCodes()
    }
}

// MARK: - Fallback Repository (hardcoded — used in Previews & tests)

public struct FallbackDialCodeRepository: DialCodeRepositoryProtocol {
    public init() {}

    public func fetchDialCodes() async -> [DialCode] {
        DialCode.fallback
    }
}

// MARK: - Hardcoded fallback list

public extension DialCode {
    static let fallback: [DialCode] = [
        DialCode(country: "Mexico",               iso: "MX", dialCode: "+52",  flag: "🇲🇽"),
        DialCode(country: "United States",        iso: "US", dialCode: "+1",   flag: "🇺🇸"),
        DialCode(country: "Canada",               iso: "CA", dialCode: "+1",   flag: "🇨🇦"),
        DialCode(country: "Colombia",             iso: "CO", dialCode: "+57",  flag: "🇨🇴"),
        DialCode(country: "Argentina",            iso: "AR", dialCode: "+54",  flag: "🇦🇷"),
        DialCode(country: "Peru",                 iso: "PE", dialCode: "+51",  flag: "🇵🇪"),
        DialCode(country: "Chile",                iso: "CL", dialCode: "+56",  flag: "🇨🇱"),
        DialCode(country: "Brazil",               iso: "BR", dialCode: "+55",  flag: "🇧🇷"),
        DialCode(country: "Venezuela",            iso: "VE", dialCode: "+58",  flag: "🇻🇪"),
        DialCode(country: "Ecuador",              iso: "EC", dialCode: "+593", flag: "🇪🇨"),
        DialCode(country: "Guatemala",            iso: "GT", dialCode: "+502", flag: "🇬🇹"),
        DialCode(country: "Cuba",                 iso: "CU", dialCode: "+53",  flag: "🇨🇺"),
        DialCode(country: "Dominican Republic",   iso: "DO", dialCode: "+1",   flag: "🇩🇴"),
        DialCode(country: "Spain",                iso: "ES", dialCode: "+34",  flag: "🇪🇸"),
        DialCode(country: "United Kingdom",       iso: "GB", dialCode: "+44",  flag: "🇬🇧"),
        DialCode(country: "France",               iso: "FR", dialCode: "+33",  flag: "🇫🇷"),
        DialCode(country: "Germany",              iso: "DE", dialCode: "+49",  flag: "🇩🇪"),
        DialCode(country: "Italy",                iso: "IT", dialCode: "+39",  flag: "🇮🇹"),
        DialCode(country: "Portugal",             iso: "PT", dialCode: "+351", flag: "🇵🇹"),
        DialCode(country: "Netherlands",          iso: "NL", dialCode: "+31",  flag: "🇳🇱"),
        DialCode(country: "Belgium",              iso: "BE", dialCode: "+32",  flag: "🇧🇪"),
        DialCode(country: "Switzerland",          iso: "CH", dialCode: "+41",  flag: "🇨🇭"),
        DialCode(country: "Ireland",              iso: "IE", dialCode: "+353", flag: "🇮🇪"),
        DialCode(country: "Sweden",               iso: "SE", dialCode: "+46",  flag: "🇸🇪"),
        DialCode(country: "Norway",               iso: "NO", dialCode: "+47",  flag: "🇳🇴"),
        DialCode(country: "Denmark",              iso: "DK", dialCode: "+45",  flag: "🇩🇰"),
        DialCode(country: "Poland",               iso: "PL", dialCode: "+48",  flag: "🇵🇱"),
        DialCode(country: "Austria",              iso: "AT", dialCode: "+43",  flag: "🇦🇹"),
        DialCode(country: "Czechia",              iso: "CZ", dialCode: "+420", flag: "🇨🇿"),
        DialCode(country: "Romania",              iso: "RO", dialCode: "+40",  flag: "🇷🇴"),
        DialCode(country: "Türkiye",              iso: "TR", dialCode: "+90",  flag: "🇹🇷"),
        DialCode(country: "Russia",               iso: "RU", dialCode: "+7",   flag: "🇷🇺"),
        DialCode(country: "Ukraine",              iso: "UA", dialCode: "+380", flag: "🇺🇦"),
        DialCode(country: "Japan",                iso: "JP", dialCode: "+81",  flag: "🇯🇵"),
        DialCode(country: "China",                iso: "CN", dialCode: "+86",  flag: "🇨🇳"),
        DialCode(country: "South Korea",          iso: "KR", dialCode: "+82",  flag: "🇰🇷"),
        DialCode(country: "India",                iso: "IN", dialCode: "+91",  flag: "🇮🇳"),
        DialCode(country: "Philippines",          iso: "PH", dialCode: "+63",  flag: "🇵🇭"),
        DialCode(country: "Thailand",             iso: "TH", dialCode: "+66",  flag: "🇹🇭"),
        DialCode(country: "Vietnam",              iso: "VN", dialCode: "+84",  flag: "🇻🇳"),
        DialCode(country: "Indonesia",            iso: "ID", dialCode: "+62",  flag: "🇮🇩"),
        DialCode(country: "Malaysia",             iso: "MY", dialCode: "+60",  flag: "🇲🇾"),
        DialCode(country: "Singapore",            iso: "SG", dialCode: "+65",  flag: "🇸🇬"),
        DialCode(country: "Israel",               iso: "IL", dialCode: "+972", flag: "🇮🇱"),
        DialCode(country: "United Arab Emirates", iso: "AE", dialCode: "+971", flag: "🇦🇪"),
        DialCode(country: "Saudi Arabia",         iso: "SA", dialCode: "+966", flag: "🇸🇦"),
        DialCode(country: "Egypt",                iso: "EG", dialCode: "+20",  flag: "🇪🇬"),
        DialCode(country: "Morocco",              iso: "MA", dialCode: "+212", flag: "🇲🇦"),
        DialCode(country: "Nigeria",              iso: "NG", dialCode: "+234", flag: "🇳🇬"),
        DialCode(country: "South Africa",         iso: "ZA", dialCode: "+27",  flag: "🇿🇦"),
        DialCode(country: "Australia",            iso: "AU", dialCode: "+61",  flag: "🇦🇺"),
        DialCode(country: "New Zealand",          iso: "NZ", dialCode: "+64",  flag: "🇳🇿"),
    ]
}
