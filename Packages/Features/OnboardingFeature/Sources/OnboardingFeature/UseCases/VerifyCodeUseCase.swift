import Foundation
import PersistenceFramework

// MARK: - Protocol
public protocol VerifyCodeUseCaseProtocol {
    func execute(email: String, code: String) async throws -> VerifyCodeResult
}

// MARK: - Result
public struct VerifyCodeResult {
    public let success: Bool
    public let userId: String
    public let deviceId: String
}

// MARK: - Implementation
public final class VerifyCodeUseCase: VerifyCodeUseCaseProtocol {
    private let authService: AuthServiceProtocol
    private let keychainManager: KeychainManager
    
    public init(
        authService: AuthServiceProtocol,
        keychainManager: KeychainManager = .shared
    ) {
        self.authService = authService
        self.keychainManager = keychainManager
    }
    
    public func execute(email: String, code: String) async throws -> VerifyCodeResult {
        let response = try await authService.registerComplete(
            email: email,
            verificationCode: code
        )
        
        guard response.data.authCode == "SUCCESS" else {
            throw VerifyCodeError.invalidCode
        }
        
        // Save tokens to Keychain
        try keychainManager.saveAuthTokens(
            accessToken: response.data.authTokenResponse.accessToken,
            refreshToken: response.data.authTokenResponse.refreshToken,
            userId: response.data.userId,
            deviceId: response.data.deviceId,
            firebaseToken: response.data.firebaseToken
        )
        
        return VerifyCodeResult(
            success: true,
            userId: response.data.userId,
            deviceId: response.data.deviceId
        )
    }
}

// MARK: - Errors
public enum VerifyCodeError: LocalizedError {
    case invalidCode
    case tokenSaveFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Código de verificación inválido"
        case .tokenSaveFailed:
            return "Error al guardar la sesión"
        }
    }
}
