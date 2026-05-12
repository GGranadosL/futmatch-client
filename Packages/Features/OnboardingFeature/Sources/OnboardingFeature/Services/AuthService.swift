import Foundation
import NetworkFramework
import PersistenceFramework

// MARK: - Protocol
public protocol AuthServiceProtocol {
    func registerStart(_ request: RegisterStartRequest) async throws -> RegisterStartResponse
    func registerComplete(email: String, verificationCode: String) async throws -> RegisterCompleteResponse
    func registerResendCode(email: String) async throws -> ResendRegistrationCodeResponse
    func signIn(email: String, password: String, deviceId: String?) async throws -> SignInResponse
    func mfaSend(userId: String, deviceId: String) async throws -> MFASendResponse
    func mfaVerify(userId: String, deviceId: String, code: String) async throws -> MFAVerifyResponse
    func forgotPassword(email: String) async throws -> ForgotPasswordResponse
    func verifyResetMFA(userId: String, code: String) async throws -> VerifyResetMFAResponse
    func resetPassword(newPassword: String, resetToken: String) async throws -> ResetPasswordResponse
    func refreshToken(userId: String, deviceId: String, refreshToken: String) async throws -> RefreshTokenResponse
    func signOut() async throws -> SignOutResponse
}

// MARK: - Implementation
public class AuthService: AuthServiceProtocol {
    private let apiClient: APIClient
    private let keychainManager: KeychainManager
    
    private let tokenKey = "auth_token"
    private let refreshTokenKey = "refresh_token"
    
    public init(
        apiClient: APIClient = .shared,
        keychainManager: KeychainManager = .shared
    ) {
        self.apiClient = apiClient
        self.keychainManager = keychainManager
    }
    
    // MARK: - Register
    
    public func registerStart(_ request: RegisterStartRequest) async throws -> RegisterStartResponse {
        let endpoint = AuthEndpoint.registerStart(request)
        let response: RegisterStartResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    public func registerComplete(email: String, verificationCode: String) async throws -> RegisterCompleteResponse {
        let request = RegisterCompleteRequest(email: email, verificationCode: verificationCode)
        let endpoint = AuthEndpoint.registerComplete(request)
        let response: RegisterCompleteResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    public func registerResendCode(email: String) async throws -> ResendRegistrationCodeResponse {
        let request = ResendRegistrationCodeRequest(email: email)
        let endpoint = AuthEndpoint.registerResendCode(request)
        let response: ResendRegistrationCodeResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    // MARK: - Sign In
    
    public func signIn(email: String, password: String, deviceId: String? = nil) async throws -> SignInResponse {
        let request = SignInRequest(email: email, password: password, deviceId: deviceId)
        let endpoint = AuthEndpoint.signIn(request)
        let response: SignInResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    // MARK: - MFA
    
    public func mfaSend(userId: String, deviceId: String) async throws -> MFASendResponse {
        let request = MFASendRequest(userId: userId, deviceId: deviceId)
        let endpoint = AuthEndpoint.mfaSend(request)
        let response: MFASendResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    public func mfaVerify(userId: String, deviceId: String, code: String) async throws -> MFAVerifyResponse {
        let request = MFAVerifyRequest(userId: userId, deviceId: deviceId, code: code)
        let endpoint = AuthEndpoint.mfaVerify(request)
        let response: MFAVerifyResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    // MARK: - Forgot Password
    
    public func forgotPassword(email: String) async throws -> ForgotPasswordResponse {
        let endpoint = AuthEndpoint.forgotPassword(email: email)
        let response: ForgotPasswordResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    public func verifyResetMFA(userId: String, code: String) async throws -> VerifyResetMFAResponse {
        let request = VerifyResetMFARequest(userId: userId, code: code)
        let endpoint = AuthEndpoint.verifyResetMFA(request)
        let response: VerifyResetMFAResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    public func resetPassword(newPassword: String, resetToken: String) async throws -> ResetPasswordResponse {
        let request = ResetPasswordRequest(newPassword: newPassword)
        let endpoint = AuthEndpoint.resetPassword(request, resetToken: resetToken)
        let response: ResetPasswordResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    // MARK: - Refresh Token
    
    public func refreshToken(userId: String, deviceId: String, refreshToken: String) async throws -> RefreshTokenResponse {
        let request = RefreshTokenRequest(userId: userId, deviceId: deviceId, refreshToken: refreshToken)
        let endpoint = AuthEndpoint.refreshToken(request)
        let response: RefreshTokenResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    // MARK: - Sign Out
    
    public func signOut() async throws -> SignOutResponse {
        guard let deviceId = try keychainManager.retrieve(for: .deviceId) else {
            throw AuthError.deviceIdNotFound
        }
        let endpoint = AuthEndpoint.signOut(deviceId: deviceId)
        let response: SignOutResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
    
    // MARK: - Token Management
    
    public func saveTokens(_ token: AuthToken) throws {
        try keychainManager.save(token.accessToken, forKey: tokenKey)
        try keychainManager.save(token.refreshToken, forKey: refreshTokenKey)
    }
    
    public func getAccessToken() throws -> String? {
        return try keychainManager.retrieve(forKey: tokenKey)
    }
    
    public func getRefreshToken() throws -> String? {
        return try keychainManager.retrieve(forKey: refreshTokenKey)
    }
    
    public func clearTokens() throws {
        try keychainManager.delete(forKey: tokenKey)
        try keychainManager.delete(forKey: refreshTokenKey)
    }
    
    public func isAuthenticated() -> Bool {
        do {
            return try getAccessToken() != nil
        } catch {
            return false
        }
    }
}

// MARK: - Auth Errors
public enum AuthError: LocalizedError {
    case deviceIdNotFound
    case invalidCredentials
    case tokenExpired
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .deviceIdNotFound:
            return "No se encontró el identificador del dispositivo"
        case .invalidCredentials:
            return "Email o contraseña incorrectos"
        case .tokenExpired:
            return "La sesión ha expirado"
        case .networkError:
            return "Error de conexión"
        }
    }
}
