import Foundation
import SharedModels

// MARK: - Resolve

/// Body of `POST /auth/google/resolve`.
///
/// `deviceId` mirrors `SignInRequest`: the stored value is sent when this device
/// is already trusted, and omitted on a first sign-in so the backend mints one.
public struct GoogleResolveRequest: Codable {
    public let idToken: String
    public let deviceId: String?

    public init(idToken: String, deviceId: String? = nil) {
        self.idToken = idToken
        self.deviceId = deviceId
    }
}

// MARK: - Register

/// Source the backend should use for the new account's avatar.
///
/// `google` makes the backend import the `picture` URL from the verified token
/// server-side. `custom` creates the account without an avatar, and the client
/// uploads the picked image afterwards through `/user/profile-pic`.
public enum ProfilePictureSource: String, Codable {
    case google = "GOOGLE"
    case custom = "CUSTOM"
}

/// Body of `POST /auth/google/register`.
///
/// There is deliberately no `email` and no `password`: the backend takes the
/// email from the verified ID token, and Google accounts are stored with
/// `users.password = null`.
public struct GoogleRegisterRequest: Codable {
    public let idToken: String
    public let name: String
    public let lastName: String
    public let phone: String
    public let country: String
    public let birthDate: Int64 // timestamp in milliseconds
    public let gender: Gender
    public let playerPosition: PlayerPosition
    public let level: PlayerLevel
    public let profilePictureSource: ProfilePictureSource
    public let deviceId: String?

    public init(
        idToken: String,
        name: String,
        lastName: String,
        phone: String,
        country: String,
        birthDate: Int64,
        gender: Gender,
        playerPosition: PlayerPosition,
        level: PlayerLevel,
        profilePictureSource: ProfilePictureSource,
        deviceId: String? = nil
    ) {
        self.idToken = idToken
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
}

// MARK: - Response

/// Shared envelope for both Google endpoints.
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
public struct GoogleAuthResponse: Codable {
    public let data: ResponseData

    public struct ResponseData: Codable {
        /// Discriminator used by `/auth/google/*`.
        public let flow: String?
        /// Same role, under the name the other auth endpoints use. Accepted so a
        /// backend that reuses the standard envelope here still decodes.
        public let authCode: String?
        /// The session, when the backend nests it — confirmed shape for
        /// `AUTHENTICATED` on `/auth/google/resolve`:
        /// `{"data":{"flow":"AUTHENTICATED","authResponse":{...}}}`.
        public let authResponse: NestedSession?
        /// Same fields, flat under `data` — kept in case `/auth/google/register`
        /// (unverified as of this writing) or a future backend revision doesn't nest.
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

    /// `true` when no Google identity exists yet and the client must run onboarding.
    public var requiresSignUp: Bool {
        data.outcome == "SIGN_UP_REQUIRED"
    }

    /// The authenticated session, or `nil` when the payload carries none.
    ///
    /// Presence of the tokens is the test rather than an exact discriminator
    /// match: `resolve` and `register` label success differently, and a retry of
    /// `register` reports an existing session. Tries the nested `authResponse`
    /// shape first, then falls back to a flat `data.*` shape.
    public var session: GoogleAuthSession? {
        if let nested = data.authResponse,
           let tokens = nested.authTokenResponse,
           let userId = nested.userId,
           let deviceId = nested.deviceId {
            return GoogleAuthSession(
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
        return GoogleAuthSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            userId: userId,
            deviceId: deviceId,
            firebaseToken: data.firebaseToken
        )
    }
}

/// Tokens extracted from a Google auth response, ready for the Keychain.
public struct GoogleAuthSession: Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let userId: String
    public let deviceId: String
    public let firebaseToken: String?
}
