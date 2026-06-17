import Foundation
import PersistenceFramework

// MARK: - Protocol
public protocol LoginUseCaseProtocol {
    func execute(email: String, password: String) async throws -> LoginResult
    func sendMFACode(userId: String, deviceId: String) async throws -> MFAResult
    func verifyMFACode(userId: String, deviceId: String, code: String) async throws -> LoginResult
}

// MARK: - Result
public struct LoginResult {
    public let userId: String
    public let deviceId: String
    public let requiresMFA: Bool
    public let resendCodeTimeInSeconds: Int
    
    public init(userId: String, deviceId: String, requiresMFA: Bool = false, resendCodeTimeInSeconds: Int = 0) {
        self.userId = userId
        self.deviceId = deviceId
        self.requiresMFA = requiresMFA
        self.resendCodeTimeInSeconds = resendCodeTimeInSeconds
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
        // Get existing deviceId if available (for re-login on same device)
        let existingDeviceId = try? keychainManager.retrieve(for: .deviceId)
        
        // Call sign in API
        let response = try await authService.signIn(
            email: email,
            password: password,
            deviceId: existingDeviceId
        )
        
        // Check if MFA is required
        if response.requiresMFA {
            // Send MFA code
            let mfaResponse = try await authService.mfaSend(
                userId: response.data.userId,
                deviceId: response.data.deviceId
            )
            
            return LoginResult(
                userId: response.data.userId,
                deviceId: response.data.deviceId,
                requiresMFA: true,
                resendCodeTimeInSeconds: mfaResponse.data.resendCodeTimeInSeconds
            )
        }
        
        // No MFA required - save tokens
        guard let tokens = response.data.authTokenResponse else {
            throw AuthError.invalidCredentials
        }
        
        try keychainManager.saveAuthTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            userId: response.data.userId,
            deviceId: response.data.deviceId,
            firebaseToken: response.data.firebaseToken
        )
        
        return LoginResult(
            userId: response.data.userId,
            deviceId: response.data.deviceId,
            requiresMFA: false
        )
    }
    
    public func sendMFACode(userId: String, deviceId: String) async throws -> MFAResult {
        let response = try await authService.mfaSend(userId: userId, deviceId: deviceId)
        
        return MFAResult(
            newCodeSent: response.data.newCodeSent,
            expiresInSeconds: response.data.expiresInSeconds,
            resendCodeTimeInSeconds: response.data.resendCodeTimeInSeconds
        )
    }
    
    public func verifyMFACode(userId: String, deviceId: String, code: String) async throws -> LoginResult {
        let response = try await authService.mfaVerify(userId: userId, deviceId: deviceId, code: code)
        
        // Save tokens to Keychain
        try keychainManager.saveAuthTokens(
            accessToken: response.data.authTokenResponse.accessToken,
            refreshToken: response.data.authTokenResponse.refreshToken,
            userId: response.data.userId,
            deviceId: response.data.deviceId,
            firebaseToken: response.data.firebaseToken
        )
        
        return LoginResult(
            userId: response.data.userId,
            deviceId: response.data.deviceId,
            requiresMFA: false
        )
    }
}
