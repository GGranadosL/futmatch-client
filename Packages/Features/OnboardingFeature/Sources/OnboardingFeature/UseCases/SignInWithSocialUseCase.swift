import Foundation
import PersistenceFramework

// MARK: - Protocol
public protocol SignInWithSocialUseCaseProtocol {
    func execute(credential: SocialCredential) async throws -> SocialSignInOutcome
}

// MARK: - Result

/// What `/auth/{provider}/resolve` decided about this identity.
public enum SocialSignInOutcome: Equatable {
    /// An account already exists and the session is now in the Keychain.
    case authenticated
    /// No identity exists yet — the client must run onboarding and finish with
    /// `/auth/{provider}/register`.
    case signUpRequired
    /// A Futmatch account already owns this email. The provider has to be added to
    /// it — which takes the account's password and an emailed code on top of this
    /// token — rather than creating a second account. Matching emails alone never
    /// link anything.
    case linkRequired(linkAttemptToken: String)
}

// MARK: - Implementation
public final class SignInWithSocialUseCase: SignInWithSocialUseCaseProtocol {
    private let authService: AuthServiceProtocol
    private let keychainManager: KeychainManaging

    public init(
        authService: AuthServiceProtocol,
        keychainManager: KeychainManaging = KeychainManager.shared
    ) {
        self.authService = authService
        self.keychainManager = keychainManager
    }

    public func execute(credential: SocialCredential) async throws -> SocialSignInOutcome {
        // Send the stored device id when this device is already trusted, exactly
        // as `LoginUseCase` does — it's what lets the backend skip a re-challenge.
        let existingDeviceId = try? keychainManager.retrieve(for: .deviceId)

        let response = try await authService.socialResolve(
            provider: credential.provider,
            idToken: credential.idToken,
            nonce: credential.nonce,
            deviceId: existingDeviceId
        )

        if response.requiresSignUp {
            return .signUpRequired
        }

        // Before the session guard: `LINK_REQUIRED` legitimately carries no tokens,
        // and would otherwise be reported as a missing session.
        if response.requiresLink {
            guard let linkAttemptToken = response.linkAttemptToken else {
                throw AuthError.missingLinkAttemptToken
            }
            return .linkRequired(linkAttemptToken: linkAttemptToken)
        }

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

        return .authenticated
    }
}
