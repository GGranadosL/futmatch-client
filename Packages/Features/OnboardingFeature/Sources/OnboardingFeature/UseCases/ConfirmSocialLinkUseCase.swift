import Foundation
import PersistenceFramework

// MARK: - Protocol
public protocol ConfirmSocialLinkUseCaseProtocol {
    /// Third and final proof: the code emailed to the existing account. On success
    /// the backend creates the identity and answers with a normal session, which
    /// this saves to the Keychain.
    func execute(linkAttemptToken: String, code: String, account: SocialAccount) async throws
}

// MARK: - Implementation
public struct ConfirmSocialLinkUseCase: ConfirmSocialLinkUseCaseProtocol {
    private let authService: AuthServiceProtocol
    private let socialAuth: SocialAuthProviding
    private let keychainManager: KeychainManaging

    public init(
        authService: AuthServiceProtocol,
        socialAuth: SocialAuthProviding,
        keychainManager: KeychainManaging = KeychainManager.shared
    ) {
        self.authService = authService
        self.socialAuth = socialAuth
        self.keychainManager = keychainManager
    }

    public func execute(linkAttemptToken: String, code: String, account: SocialAccount) async throws {
        let credential = try await freshCredential(for: account)
        let existingDeviceId = try? keychainManager.retrieve(for: .deviceId)

        let request = SocialLinkConfirmRequest(
            provider: credential.provider,
            linkAttemptToken: linkAttemptToken,
            code: code,
            idToken: credential.idToken,
            authorizationCode: credential.authorizationCode,
            nonce: credential.nonce,
            deviceId: existingDeviceId
        )

        let response = try await authService.confirmSocialLink(request)

        guard let session = response.session else {
            throw AuthError.missingSocialSession
        }

        try keychainManager.saveAuthTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userId: session.userId,
            deviceId: session.deviceId,
            firebaseToken: session.firebaseToken
        )
    }

    /// The backend verifies the provider token again at confirm time, so it has to
    /// still be valid — and several minutes may have passed typing a password and
    /// waiting for an email.
    private func freshCredential(for account: SocialAccount) async throws -> SocialCredential {
        switch account.provider {
        case .google:
            // Google's SDK can mint a new token silently. Falling back to the
            // original is deliberate: a refresh failure here is not worth losing
            // the whole attempt over when the token in hand may still be good, and
            // the backend is the one that decides either way.
            if let refreshed = try? await socialAuth.refreshedCredential(matching: account.draftIdentity) {
                return refreshed
            }
            return account.credential
        case .apple:
            // Apple has no silent refresh — `refreshedCredential` always throws
            // `reauthenticationRequired` — so the credential captured when the user
            // tapped the button is the only one available. Its lifetime (~10 min)
            // is the real ceiling on this flow, tighter than the attempt token's.
            // Surfacing it here means the user is told to start over instead of
            // watching the backend reject a token we already knew was dead.
            guard !account.credential.isExpired else {
                throw SocialAuthError.reauthenticationRequired
            }
            return account.credential
        }
    }
}
