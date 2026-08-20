import Foundation
import SharedModels
import PersistenceFramework

// MARK: - Input

/// Everything the onboarding form collected that Google could not provide.
///
/// The email is absent on purpose: `/auth/google/register` reads it from the
/// verified ID token, and a client-supplied email is never trusted as identity.
public struct GoogleRegistrationInput: Equatable {
    public let name: String
    public let lastName: String
    public let phone: String
    public let country: String
    public let birthDate: Int64 // timestamp in milliseconds
    public let gender: Gender
    public let playerPosition: PlayerPosition
    public let level: PlayerLevel
    public let profilePictureSource: ProfilePictureSource

    public init(
        name: String,
        lastName: String,
        phone: String,
        country: String,
        birthDate: Int64,
        gender: Gender,
        playerPosition: PlayerPosition,
        level: PlayerLevel,
        profilePictureSource: ProfilePictureSource
    ) {
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
public protocol RegisterGoogleUserUseCaseProtocol {
    func execute(_ input: GoogleRegistrationInput) async throws
}

// MARK: - Implementation
public final class RegisterGoogleUserUseCase: RegisterGoogleUserUseCaseProtocol {
    private let authService: AuthServiceProtocol
    private let googleAuth: GoogleAuthProviding
    private let keychainManager: KeychainManaging

    public init(
        authService: AuthServiceProtocol,
        googleAuth: GoogleAuthProviding,
        keychainManager: KeychainManaging = KeychainManager.shared
    ) {
        self.authService = authService
        self.googleAuth = googleAuth
        self.keychainManager = keychainManager
    }

    public func execute(_ input: GoogleRegistrationInput) async throws {
        // A fresh token, never the one from the initial sign-in: the backend
        // requires an unexpired token here, and onboarding may have been resumed
        // from a draft hours later (the token itself is never persisted).
        let idToken = try await googleAuth.refreshedIdToken()
        let existingDeviceId = try? keychainManager.retrieve(for: .deviceId)

        let request = GoogleRegisterRequest(
            idToken: idToken,
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

        let response = try await authService.googleRegister(request)

        // A retry that lands on an existing identity resolves to that session
        // instead of creating a duplicate, so this reads the same either way.
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
    }
}
