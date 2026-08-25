import Foundation

/// A social identity provider FutMatch can authenticate through.
public enum AuthProvider: String, Codable, Equatable, CaseIterable {
    case google = "GOOGLE"
    case apple = "APPLE"

    /// The `iss` claim the backend keys on. Fixed per provider.
    public var issuer: String {
        switch self {
        case .google: return "https://accounts.google.com"
        case .apple: return "https://appleid.apple.com"
        }
    }
}

/// The short-lived proof a provider hands back. Never persisted, never written to
/// the onboarding draft.
///
/// `authorizationCode` and `nonce` are Apple-only: Apple's identity token has no
/// built-in replay defence the way Google's SDK provides, so the nonce binds this
/// credential to the request that requested it, and the authorization code is what
/// the backend exchanges server-side for a revocable refresh token.
public struct SocialCredential: Equatable {
    public let provider: AuthProvider
    public let idToken: String
    public let authorizationCode: String?
    public let nonce: String?
    /// From the token's `exp` claim. `nil` for Google, whose SDK can mint a fresh
    /// token silently — expiry only matters for providers that can't.
    public let expiresAt: Date?

    public init(
        provider: AuthProvider,
        idToken: String,
        authorizationCode: String? = nil,
        nonce: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.provider = provider
        self.idToken = idToken
        self.authorizationCode = authorizationCode
        self.nonce = nonce
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }
}

/// A social identity as returned by a provider's SDK.
///
/// `issuer` + `subject` form the durable identity the backend keys on
/// (`auth_identities` is unique over `(provider, issuer, provider_subject)`).
/// The email is *not* an identity key — it is carried only to show the user
/// which account they picked, and is never sent in the register request:
/// the backend reads it from the verified token itself.
public struct SocialAccount: Equatable {
    public let credential: SocialCredential
    public let issuer: String
    public let subject: String
    public let email: String
    public let givenName: String
    public let familyName: String
    /// Always `nil` for Apple — the provider never returns an avatar.
    public let pictureURL: String?

    public init(
        credential: SocialCredential,
        issuer: String,
        subject: String,
        email: String,
        givenName: String,
        familyName: String,
        pictureURL: String? = nil
    ) {
        self.credential = credential
        self.issuer = issuer
        self.subject = subject
        self.email = email
        self.givenName = givenName
        self.familyName = familyName
        self.pictureURL = pictureURL
    }

    public var provider: AuthProvider { credential.provider }

    public var draftIdentity: SocialDraftIdentity {
        SocialDraftIdentity(provider: provider, issuer: issuer, subject: subject)
    }
}

/// The durable half of a `SocialAccount` — everything needed to tell whether a
/// stored onboarding draft belongs to the account currently signing up, without
/// carrying the credential around.
public struct SocialDraftIdentity: Equatable {
    public let provider: AuthProvider
    public let issuer: String
    public let subject: String

    public init(provider: AuthProvider, issuer: String, subject: String) {
        self.provider = provider
        self.issuer = issuer
        self.subject = subject
    }
}

/// Lets the login screen drive a `fullScreenCover(item:)` straight off the
/// resolved account. The provider is part of the id: the same person's Google and
/// Apple identities are two different sign-ups.
extension SocialAccount: Identifiable {
    public var id: String { "\(provider.rawValue)|\(issuer)|\(subject)" }
}
