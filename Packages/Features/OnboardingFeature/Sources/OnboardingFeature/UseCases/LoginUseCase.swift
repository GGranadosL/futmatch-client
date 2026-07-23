import Foundation
import PersistenceFramework

// MARK: - Protocol
public protocol LoginUseCaseProtocol {
    func execute(email: String, password: String) async throws -> LoginResult
    func sendMFACode(challengeToken: String) async throws -> MFAResult
    func verifyMFACode(challengeToken: String, code: String) async throws -> LoginResult
}

// MARK: - Result
public struct LoginResult {
    public let requiresMFA: Bool
    public let resendCodeTimeInSeconds: Int
    public let challengeToken: String?

    public init(requiresMFA: Bool = false, resendCodeTimeInSeconds: Int = 0, challengeToken: String? = nil) {
        self.requiresMFA = requiresMFA
        self.resendCodeTimeInSeconds = resendCodeTimeInSeconds
        self.challengeToken = challengeToken
    }
}

public struct MFAResult {
    public let newCodeSent: Bool
    public let expiresInSeconds: Int
    public let resendCodeTimeInSeconds: Int

    public init(newCodeSent: Bool, expiresInSeconds: Int, resendCodeTimeInSeconds: Int) {
        self.newCodeSent = newCodeSent
        self.expiresInSeconds = expiresInSeconds
        self.resendCodeTimeInSeconds = resendCodeTimeInSeconds
    }
}

// MARK: - Implementation
public final class LoginUseCase: LoginUseCaseProtocol {
    private let authService: AuthServiceProtocol
    private let keychainManager: KeychainManaging

    public init(
        authService: AuthServiceProtocol,
        keychainManager: KeychainManaging = KeychainManager.shared
    ) {
        self.authService = authService
        self.keychainManager = keychainManager
    }

    public func execute(email: String, password: String) async throws -> LoginResult {
        let existingDeviceId = try? keychainManager.retrieve(for: .deviceId)

        let response = try await authService.signIn(
            email: email,
            password: password,
            deviceId: existingDeviceId
        )

        if response.requiresMFA {
            guard let challengeToken = response.data.challengeToken else {
                throw AuthError.missingChallengeToken
            }
            let mfaResponse = try await authService.mfaSend(challengeToken: challengeToken)
            return LoginResult(
                requiresMFA: true,
                resendCodeTimeInSeconds: mfaResponse.data.resendCodeTimeInSeconds,
                challengeToken: challengeToken
            )
        }

        guard let tokens = response.data.authTokenResponse,
              let userId = response.data.userId,
              let deviceId = response.data.deviceId else {
            throw AuthError.invalidCredentials
        }

        try keychainManager.saveAuthTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            userId: userId,
            deviceId: deviceId,
            firebaseToken: response.data.firebaseToken
        )

        return LoginResult(requiresMFA: false)
    }

    public func sendMFACode(challengeToken: String) async throws -> MFAResult {
        let response = try await authService.mfaSend(challengeToken: challengeToken)
        return MFAResult(
            newCodeSent: response.data.newCodeSent,
            expiresInSeconds: response.data.expiresInSeconds,
            resendCodeTimeInSeconds: response.data.resendCodeTimeInSeconds
        )
    }

    public func verifyMFACode(challengeToken: String, code: String) async throws -> LoginResult {
        let response = try await authService.mfaVerify(challengeToken: challengeToken, code: code)

        try keychainManager.saveAuthTokens(
            accessToken: response.data.authTokenResponse.accessToken,
            refreshToken: response.data.authTokenResponse.refreshToken,
            userId: response.data.userId,
            deviceId: response.data.deviceId,
            firebaseToken: response.data.firebaseToken
        )

        return LoginResult(requiresMFA: false)
    }
}
