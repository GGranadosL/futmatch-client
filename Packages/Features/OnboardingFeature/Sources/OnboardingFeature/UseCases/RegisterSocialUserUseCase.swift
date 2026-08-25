import Foundation
import SharedModels
import PersistenceFramework

// MARK: - Input

/// Everything the onboarding form collected that the provider could not supply.
///
/// The email is absent on purpose: both backends read it from the verified
/// token, and a client-supplied email is never trusted as identity.
///
/// Carries both `identity` and `credential` because the two providers need
/// different things at register time: Google asks for a freshly-minted
/// credential scoped to `identity` (its SDK can do this silently, even if the
/// draft was resumed hours later); Apple cannot mint one without presenting the
/// authorization sheet again, so its original `credential` — captured at
/// sign-up time — is sent as-is. See `RegisterSocialUserUseCase.execute`.
public struct SocialRegistrationInput: Equatable {
    public let identity: SocialDraftIdentity
    public let credential: SocialCredential
    public let name: String
    public let lastName: String
    public let phone: String
    public let country: String
    public let birthDate: Int64 // timestamp in milliseconds
    public let gender: Gender
    public let playerPosition: PlayerPosition
    public let level: PlayerLevel
    /// `nil` for Apple, which never supplies an avatar.
    public let profilePictureSource: ProfilePictureSource?

    public init(
        identity: SocialDraftIdentity,
        credential: SocialCredential,
        name: String,
        lastName: String,
        phone: String,
        country: String,
        birthDate: Int64,
        gender: Gender,
        playerPosition: PlayerPosition,
        level: PlayerLevel,
        profilePictureSource: ProfilePictureSource?
    ) {
        self.identity = identity
        self.credential = credential
        self.name = name
        self.lastName = lastName
        self.phone = phone
        self.country = country
        self.birthDate = birthDate
        self.gender = gender
        self.playerPosition = playerPosition
        self.level = level
        self.profilePictureSource = profilePictureSource
    }
}

// MARK: - Protocol
public protocol RegisterSocialUserUseCaseProtocol {
    func execute(_ input: SocialRegistrationInput) async throws
}

// MARK: - Implementation
public final class RegisterSocialUserUseCase: RegisterSocialUserUseCaseProtocol {
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

    public func execute(_ input: SocialRegistrationInput) async throws {
        let credential: SocialCredential
        switch input.credential.provider {
        case .google:
            // A fresh credential, never the one from the initial sign-in: the
            // backend requires an unexpired token here, and onboarding may have
            // been resumed from a draft hours later. Google's SDK can mint this
            // silently regardless of how much time has passed.
            credential = try await socialAuth.refreshedCredential(matching: input.identity)
        case .apple:
            // Apple cannot mint a fresh credential without presenting the
            // authorization sheet again, so `refreshedCredential` always throws
            // `SocialAuthError.reauthenticationRequired` for this provider — it is
            // not called here. Instead, `OnboardingViewModel` proactively bounces
            // back to login as soon as the credential is close to expiring (see
            // `scheduleCredentialExpiry`), which guarantees the one captured at
            // sign-up time — sent here unchanged — is still valid.
            credential = input.credential
        }
        let existingDeviceId = try? keychainManager.retrieve(for: .deviceId)

        let request = SocialRegisterRequest(
            provider: credential.provider,
            idToken: credential.idToken,
            authorizationCode: credential.authorizationCode,
            nonce: credential.nonce,
            name: input.name,
            lastName: input.lastName,
            phone: input.phone,
            country: input.country,
            birthDate: input.birthDate,
            gender: input.gender,
            playerPosition: input.playerPosition,
            level: input.level,
            profilePictureSource: input.profilePictureSource,
            deviceId: existingDeviceId
        )

        let response = try await authService.socialRegister(request)

        // A retry that lands on an existing identity resolves to that session
        // instead of creating a duplicate, so this reads the same either way.
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
}
