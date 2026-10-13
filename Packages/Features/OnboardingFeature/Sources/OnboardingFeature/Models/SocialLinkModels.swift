import Foundation

// MARK: - Start

/// Body of `POST /auth/social-link/start`.
///
/// The password is the second of the three proofs the backend requires before it
/// will add a social identity to an existing account — a valid provider token
/// alone is not enough, precisely so that matching email addresses can never link
/// two accounts on their own.
public struct SocialLinkStartRequest: Encodable {
    public let linkAttemptToken: String
    public let password: String

    public init(linkAttemptToken: String, password: String) {
        self.linkAttemptToken = linkAttemptToken
        self.password = password
    }
}

public struct SocialLinkStartResponse: Codable {
    public let data: ResponseData

    public struct ResponseData: Codable {
        public let newCodeSent: Bool
        public let expiresInSeconds: Int
        public let resendCodeTimeInSeconds: Int
    }
}

// MARK: - Confirm

/// Body of `POST /auth/social-link/{provider}/confirm`.
///
/// Same provider-dependent wire shape as `SocialResolveRequest`: Google's field is
/// `idToken`, Apple's is `identityToken` and additionally carries `nonce` and
/// `authorizationCode`. Apple's authorization code is what the backend exchanges
/// server-side for the refresh token it needs to revoke the credential when the
/// account is deleted, so it must survive from the original sign-in to here.
public struct SocialLinkConfirmRequest: Encodable {
    public let provider: AuthProvider
    public let linkAttemptToken: String
    public let code: String
    public let idToken: String
    /// Apple only.
    public let authorizationCode: String?
    /// Apple only.
    public let nonce: String?
    public let deviceId: String?

    public init(
        provider: AuthProvider,
        linkAttemptToken: String,
        code: String,
        idToken: String,
        authorizationCode: String? = nil,
        nonce: String? = nil,
        deviceId: String? = nil
    ) {
        self.provider = provider
        self.linkAttemptToken = linkAttemptToken
        self.code = code
        self.idToken = idToken
        self.authorizationCode = authorizationCode
        self.nonce = nonce
        self.deviceId = deviceId
    }

    private enum GoogleKeys: String, CodingKey { case linkAttemptToken, code, idToken, deviceId }
    private enum AppleKeys: String, CodingKey {
        case linkAttemptToken, code, identityToken, nonce, authorizationCode, deviceId
    }

    public func encode(to encoder: Encoder) throws {
        switch provider {
        case .google:
            var container = encoder.container(keyedBy: GoogleKeys.self)
            try container.encode(linkAttemptToken, forKey: .linkAttemptToken)
            try container.encode(code, forKey: .code)
            try container.encode(idToken, forKey: .idToken)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
        case .apple:
            var container = encoder.container(keyedBy: AppleKeys.self)
            try container.encode(linkAttemptToken, forKey: .linkAttemptToken)
            try container.encode(code, forKey: .code)
            try container.encode(idToken, forKey: .identityToken)
            try container.encode(nonce ?? "", forKey: .nonce)
            try container.encode(authorizationCode ?? "", forKey: .authorizationCode)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
        }
    }
}
