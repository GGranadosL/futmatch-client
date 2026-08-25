import Foundation
import SharedModels

// MARK: - Resolve

/// Body of `POST /auth/{provider}/resolve`.
///
/// The two backends use different field names for the token — Google calls it
/// `idToken` (matching its SDK), Apple calls it `identityToken` (matching
/// `ASAuthorizationAppleIDCredential.identityToken`) and additionally requires a
/// `nonce`. One Swift type still fits both: `encode(to:)` picks the wire shape by
/// `provider`, so callers and the response decoder stay provider-agnostic even
/// though the JSON differs.
public struct SocialResolveRequest: Encodable {
    public let provider: AuthProvider
    public let idToken: String
    /// Apple only. `nil` is never encoded for Google.
    public let nonce: String?
    /// Mirrors `SignInRequest`: the stored value is sent when this device is
    /// already trusted, and omitted on a first sign-in so the backend mints one.
    public let deviceId: String?

    public init(provider: AuthProvider, idToken: String, nonce: String? = nil, deviceId: String? = nil) {
        self.provider = provider
        self.idToken = idToken
        self.nonce = nonce
        self.deviceId = deviceId
    }

    private enum GoogleKeys: String, CodingKey { case idToken, deviceId }
    private enum AppleKeys: String, CodingKey { case identityToken, nonce, deviceId }

    public func encode(to encoder: Encoder) throws {
        switch provider {
        case .google:
            var container = encoder.container(keyedBy: GoogleKeys.self)
            try container.encode(idToken, forKey: .idToken)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
        case .apple:
            var container = encoder.container(keyedBy: AppleKeys.self)
            try container.encode(idToken, forKey: .identityToken)
            try container.encodeIfPresent(nonce, forKey: .nonce)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
        }
    }
}

// MARK: - Register

/// Source the backend should use for the new account's avatar.
///
/// `providerImported` makes the backend import the `picture` URL from the
/// verified Google token server-side — Apple never returns one, so this case is
/// invalid for an Apple registration and is simply never encoded. `custom`
/// creates the account without an avatar and the client uploads the picked image
/// afterwards through `/user/profile-pic`.
public enum ProfilePictureSource: String, Codable {
    case providerImported = "GOOGLE"
    case custom = "CUSTOM"
}

/// Body of `POST /auth/{provider}/register`.
///
/// There is deliberately no `email`: both backends take it from the verified
/// token (Google) or reject the request outright when it's absent (Apple), and
/// social accounts are stored with `users.password = null`. `name`/`lastName`
/// ARE sent even though the ID token might carry them (Google) or never carries
/// them (Apple) — Apple only ever hands its name over once, at the very first
/// authorization, so the client-collected value is the only one either backend
/// can rely on.
public struct SocialRegisterRequest: Encodable {
    public let provider: AuthProvider
    public let idToken: String
    /// Apple only: single-use, exchanged server-side for a revocation refresh token.
    public let authorizationCode: String?
    /// Apple only: raw nonce whose SHA-256 is the token's `nonce` claim.
    public let nonce: String?
    public let name: String
    public let lastName: String
    public let phone: String
    public let country: String
    public let birthDate: Int64 // timestamp in milliseconds
    public let gender: Gender
    public let playerPosition: PlayerPosition
    public let level: PlayerLevel
    /// Google only — Apple's register request has no such field.
    public let profilePictureSource: ProfilePictureSource?
    public let deviceId: String?

    public init(
        provider: AuthProvider,
        idToken: String,
        authorizationCode: String? = nil,
        nonce: String? = nil,
        name: String,
        lastName: String,
        phone: String,
        country: String,
        birthDate: Int64,
        gender: Gender,
        playerPosition: PlayerPosition,
        level: PlayerLevel,
        profilePictureSource: ProfilePictureSource? = nil,
        deviceId: String? = nil
    ) {
        self.provider = provider
        self.idToken = idToken
        self.authorizationCode = authorizationCode
        self.nonce = nonce
        self.name = name
        self.lastName = lastName
        self.phone = phone
        self.country = country
        self.birthDate = birthDate
        self.gender = gender
        self.playerPosition = playerPosition
        self.level = level
        self.profilePictureSource = profilePictureSource
        self.deviceId = deviceId
    }

    private enum GoogleKeys: String, CodingKey {
        case idToken, name, lastName, phone, country, birthDate, gender, playerPosition, level, profilePictureSource, deviceId
    }
    private enum AppleKeys: String, CodingKey {
        case identityToken, authorizationCode, nonce, name, lastName, phone, country, birthDate, gender, playerPosition, level, deviceId
    }

    public func encode(to encoder: Encoder) throws {
        switch provider {
        case .google:
            var container = encoder.container(keyedBy: GoogleKeys.self)
            try container.encode(idToken, forKey: .idToken)
            try container.encode(name, forKey: .name)
            try container.encode(lastName, forKey: .lastName)
            try container.encode(phone, forKey: .phone)
            try container.encode(country, forKey: .country)
            try container.encode(birthDate, forKey: .birthDate)
            try container.encode(gender, forKey: .gender)
            try container.encode(playerPosition, forKey: .playerPosition)
            try container.encode(level, forKey: .level)
            try container.encode(profilePictureSource ?? .custom, forKey: .profilePictureSource)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
        case .apple:
            var container = encoder.container(keyedBy: AppleKeys.self)
            try container.encode(idToken, forKey: .identityToken)
            try container.encode(authorizationCode ?? "", forKey: .authorizationCode)
            try container.encode(nonce ?? "", forKey: .nonce)
            try container.encode(name, forKey: .name)
            try container.encode(lastName, forKey: .lastName)
            try container.encode(phone, forKey: .phone)
            try container.encode(country, forKey: .country)
            try container.encode(birthDate, forKey: .birthDate)
            try container.encode(gender, forKey: .gender)
            try container.encode(playerPosition, forKey: .playerPosition)
            try container.encode(level, forKey: .level)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
        }
    }
}

// MARK: - Response

/// Shared envelope for both providers' resolve/register endpoints — the backends
/// deliberately mirror the same shape.
///
/// `resolve` answers `SIGN_UP_REQUIRED` (no session) or `AUTHENTICATED` (full
/// session). `register` answers with a session too — and, when a retry lands on
/// an identity that already exists, it resolves to the existing session rather
/// than creating a duplicate.
///
/// Every field is optional on purpose. The sign-up-required payload is just
/// `{"data":{"flow":"SIGN_UP_REQUIRED"}}` — no tokens, no ids — so any required
/// field turns a perfectly valid answer into a decode failure that surfaces to
/// the user as "no se han podido leer los datos" with no clue what went wrong.
/// Read `session` instead of poking at the fields.
public struct SocialAuthResponse: Codable {
    public let data: ResponseData

    public struct ResponseData: Codable {
        /// Discriminator used by `/auth/{provider}/*`.
        public let flow: String?
        /// Same role, under the name the other auth endpoints use. Accepted so a
        /// backend that reuses the standard envelope here still decodes.
        public let authCode: String?
        /// The session, when the backend nests it — confirmed shape for
        /// `AUTHENTICATED` on `/auth/{provider}/resolve`:
        /// `{"data":{"flow":"AUTHENTICATED","authResponse":{...}}}`.
        public let authResponse: NestedSession?
        /// Same fields, flat under `data` — kept in case a register response
        /// doesn't nest.
        public let userId: String?
        public let deviceId: String?
        public let authTokenResponse: AuthTokenResponse?
        public let firebaseToken: String?

        /// Whichever discriminator the payload actually carried.
        var outcome: String? { flow ?? authCode ?? authResponse?.authCode }
    }

    /// Session fields as they arrive nested under `data.authResponse`.
    public struct NestedSession: Codable {
        public let userId: String?
        public let deviceId: String?
        public let authTokenResponse: AuthTokenResponse?
        public let firebaseToken: String?
        public let authCode: String?
    }

    public struct AuthTokenResponse: Codable {
        public let accessToken: String
        public let refreshToken: String
    }

    /// `true` when no identity exists yet and the client must run onboarding.
    public var requiresSignUp: Bool {
        data.outcome == "SIGN_UP_REQUIRED"
    }

    /// The authenticated session, or `nil` when the payload carries none.
    ///
    /// Presence of the tokens is the test rather than an exact discriminator
    /// match: `resolve` and `register` label success differently, and a retry of
    /// `register` reports an existing session. Tries the nested `authResponse`
    /// shape first, then falls back to a flat `data.*` shape.
    public var session: SocialAuthSession? {
        if let nested = data.authResponse,
           let tokens = nested.authTokenResponse,
           let userId = nested.userId,
           let deviceId = nested.deviceId {
            return SocialAuthSession(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                userId: userId,
                deviceId: deviceId,
                firebaseToken: nested.firebaseToken
            )
        }
        guard let tokens = data.authTokenResponse,
              let userId = data.userId,
              let deviceId = data.deviceId else { return nil }
        return SocialAuthSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            userId: userId,
            deviceId: deviceId,
            firebaseToken: data.firebaseToken
        )
    }
}

/// Tokens extracted from a social auth response, ready for the Keychain.
public struct SocialAuthSession: Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let userId: String
    public let deviceId: String
    public let firebaseToken: String?
}
