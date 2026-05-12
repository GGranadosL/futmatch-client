import Foundation

// MARK: - Forgot Password Use Case

public protocol ForgotPasswordUseCaseProtocol {
    func execute(email: String) async throws -> ForgotPasswordResponse
}

public final class ForgotPasswordUseCase: ForgotPasswordUseCaseProtocol {
    private let authService: AuthServiceProtocol
    
    public init(authService: AuthServiceProtocol) {
        self.authService = authService
    }
    
    public func execute(email: String) async throws -> ForgotPasswordResponse {
        return try await authService.forgotPassword(email: email)
    }
}

// MARK: - Verify Reset MFA Use Case

public protocol VerifyResetMFAUseCaseProtocol {
    func execute(userId: String, code: String) async throws -> VerifyResetMFAResponse
}

public final class VerifyResetMFAUseCase: VerifyResetMFAUseCaseProtocol {
    private let authService: AuthServiceProtocol
    
    public init(authService: AuthServiceProtocol) {
        self.authService = authService
    }
    
    public func execute(userId: String, code: String) async throws -> VerifyResetMFAResponse {
        return try await authService.verifyResetMFA(userId: userId, code: code)
    }
}

// MARK: - Reset Password Use Case

public protocol ResetPasswordUseCaseProtocol {
    func execute(newPassword: String, resetToken: String) async throws -> ResetPasswordResponse
}

public final class ResetPasswordUseCase: ResetPasswordUseCaseProtocol {
    private let authService: AuthServiceProtocol
    
    public init(authService: AuthServiceProtocol) {
        self.authService = authService
    }
    
    public func execute(newPassword: String, resetToken: String) async throws -> ResetPasswordResponse {
        return try await authService.resetPassword(newPassword: newPassword, resetToken: resetToken)
    }
}
