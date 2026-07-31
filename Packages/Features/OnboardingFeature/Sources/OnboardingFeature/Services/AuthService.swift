import Foundation
import NetworkFramework

// MARK: - Protocol
public protocol AuthServiceProtocol {
    func registerStart(_ request: RegisterStartRequest) async throws -> RegisterStartResponse
    func registerComplete(email: String, verificationCode: String) async throws -> RegisterCompleteResponse
    func registerResendCode(email: String) async throws -> ResendRegistrationCodeResponse
    func signIn(email: String, password: String, deviceId: String?) async throws -> SignInResponse
    func mfaSend(challengeToken: String) async throws -> MFASendResponse
    func mfaVerify(challengeToken: String, code: String) async throws -> MFAVerifyResponse
    func forgotPassword(email: String) async throws -> ForgotPasswordResponse
    func verifyResetMFA(email: String, code: String) async throws -> VerifyResetMFAResponse
    func resetPassword(newPassword: String, resetToken: String) async throws -> ResetPasswordResponse
    func refreshToken(refreshToken: String) async throws -> RefreshTokenResponse
    func signOut() async throws -> SignOutResponse
}

// MARK: - Implementation
public class AuthService: AuthServiceProtocol {
    private let apiClient: APIClient

    public init(
        apiClient: APIClient = .shared
    ) {
        self.apiClient = apiClient
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

    public func mfaSend(challengeToken: String) async throws -> MFASendResponse {
        let request = MFASendRequest(challengeToken: challengeToken)
        let endpoint = AuthEndpoint.mfaSend(request)
        let response: MFASendResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }

    public func mfaVerify(challengeToken: String, code: String) async throws -> MFAVerifyResponse {
        let request = MFAVerifyRequest(challengeToken: challengeToken, code: code)
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
    
    public func verifyResetMFA(email: String, code: String) async throws -> VerifyResetMFAResponse {
        let request = VerifyResetMFARequest(email: email, code: code)
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

    public func refreshToken(refreshToken: String) async throws -> RefreshTokenResponse {
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        let endpoint = AuthEndpoint.refreshToken(request)
        let response: RefreshTokenResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }

    // MARK: - Sign Out

    public func signOut() async throws -> SignOutResponse {
        let endpoint = AuthEndpoint.signOut
        let response: SignOutResponse = try await apiClient.request(endpoint: endpoint)
        return response
    }
}

// MARK: - Auth Errors
public enum AuthError: LocalizedError {
    case invalidCredentials
    case tokenExpired
    case networkError
    case firebaseSignInFailed
    case missingChallengeToken

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Email o contraseña incorrectos"
        case .tokenExpired:
            return "La sesión ha expirado"
        case .networkError:
            return "Error de conexión"
        case .firebaseSignInFailed:
            return "No se pudo completar la autenticación. Intenta de nuevo."
        case .missingChallengeToken:
            return "No se pudo continuar con la verificación. Intenta iniciar sesión de nuevo."
        }
    }
}
