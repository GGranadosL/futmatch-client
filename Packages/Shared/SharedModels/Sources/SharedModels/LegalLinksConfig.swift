import Foundation

/// Abstracts the Remote-Config-backed legal/help URLs shown in Settings and
/// during onboarding (terms/privacy acceptance). The concrete Firebase
/// implementation (`LegalLinksRemoteConfigRepository`) lives in the app
/// target so feature packages stay Firebase-free.
public protocol LegalLinksProtocol {
    var helpURL: URL { get }
    var termsURL: URL { get }
    var privacyURL: URL { get }
}

/// JSON payload shape for the single `settings_legal_urls` Remote Config
/// parameter (Value type: JSON in the Firebase console).
public struct LegalLinksPayload: Codable {
    public let helpUrl: String
    public let termsUrl: String
    public let privacyUrl: String

    enum CodingKeys: String, CodingKey {
        case helpUrl = "help_url"
        case termsUrl = "terms_url"
        case privacyUrl = "privacy_url"
    }

    public init(helpUrl: String, termsUrl: String, privacyUrl: String) {
        self.helpUrl = helpUrl
        self.termsUrl = termsUrl
        self.privacyUrl = privacyUrl
    }
}

// MARK: - Default implementation (UserDefaults-backed, set by the app target)

/// Reads the payload cached by `LegalLinksRemoteConfigRepository` in
/// UserDefaults. Used as a drop-in when no custom implementation is
/// injected, falling back to the current production URLs if Remote Config
/// hasn't been fetched yet.
public struct LegalLinksConfig: LegalLinksProtocol {
    public static let cacheKey = "fm_settings_legal_urls_cache_v1"

    private static let defaultPayload = LegalLinksPayload(
        helpUrl: "https://futmatch.mx/faq",
        termsUrl: "https://futmatch.mx/terminos",
        privacyUrl: "https://futmatch.mx/privacidad"
    )

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var payload: LegalLinksPayload {
        guard let data = defaults.data(forKey: Self.cacheKey),
              let decoded = try? JSONDecoder().decode(LegalLinksPayload.self, from: data)
        else {
            return Self.defaultPayload
        }
        return decoded
    }

    public var helpURL: URL {
        URL(string: payload.helpUrl) ?? URL(string: Self.defaultPayload.helpUrl)!
    }

    public var termsURL: URL {
        URL(string: payload.termsUrl) ?? URL(string: Self.defaultPayload.termsUrl)!
    }

    public var privacyURL: URL {
        URL(string: payload.privacyUrl) ?? URL(string: Self.defaultPayload.privacyUrl)!
    }
}
