import Foundation
import PersistenceFramework

// MARK: - Protocol
public protocol SignInWithGoogleUseCaseProtocol {
    func execute(idToken: String) async throws -> GoogleSignInOutcome
}

// MARK: - Result

/// What `/auth/google/resolve` decided about this Google identity.
public enum GoogleSignInOutcome: Equatable {
    /// An account already exists and the session is now in the Keychain.
    case authenticated
    /// No Google identity exists yet — the client must run onboarding and finish
    /// with `/auth/google/register`.
    case signUpRequired
}

// MARK: - Implementation
public final class SignInWithGoogleUseCase: SignInWithGoogleUseCaseProtocol {
    private let authService: AuthServiceProtocol
    private let keychainManager: KeychainManaging

    public init(
        authService: AuthServiceProtocol,
        keychainManager: KeychainManaging = KeychainManager.shared
    ) {
        self.authService = authService
        self.keychainManager = keychainManager
    }

    public func execute(idToken: String) async throws -> GoogleSignInOutcome {
        // Send the stored device id when this device is already trusted, exactly
        // as `LoginUseCase` does — it's what lets the backend skip a re-challenge.
        let existingDeviceId = try? keychainManager.retrieve(for: .deviceId)

        let response = try await authService.googleResolve(
            idToken: idToken,
            deviceId: existingDeviceId
        )

        if response.requiresSignUp {
            return .signUpRequired
        }

        guard let session = response.session else {
            throw AuthError.missingGoogleSession
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
