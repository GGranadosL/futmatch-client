import Foundation
import SwiftUI

// MARK: - Forgot Password Flow State

public enum ForgotPasswordFlowState {
    case email
    case verification(userId: String, email: String)
    case newPassword(userId: String, resetToken: String)
    case success
}

// MARK: - Forgot Password Coordinator ViewModel

@MainActor
public final class ForgotPasswordCoordinatorViewModel: ObservableObject {
    @Published public private(set) var currentState: ForgotPasswordFlowState = .email
    @Published public private(set) var isLoading = false
    @Published public var error: Error?
    
    @Published public private(set) var resendCodeTimeInSeconds: Int = 60 // Default value
    
    private let forgotPasswordUseCase: ForgotPasswordUseCaseProtocol
    private let verifyResetMFAUseCase: VerifyResetMFAUseCaseProtocol
    private let resetPasswordUseCase: ResetPasswordUseCaseProtocol
    
    public init(
        forgotPasswordUseCase: ForgotPasswordUseCaseProtocol,
        verifyResetMFAUseCase: VerifyResetMFAUseCaseProtocol,
        resetPasswordUseCase: ResetPasswordUseCaseProtocol
    ) {
        self.forgotPasswordUseCase = forgotPasswordUseCase
        self.verifyResetMFAUseCase = verifyResetMFAUseCase
        self.resetPasswordUseCase = resetPasswordUseCase
    }
    
    // MARK: - Actions
    
    public func sendForgotPasswordEmail(_ email: String) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await forgotPasswordUseCase.execute(email: email)
            resendCodeTimeInSeconds = response.data.resendCodeTimeInSeconds
            currentState = .verification(userId: response.data.userId, email: email)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    public func verifyCode(_ code: String, userId: String) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await verifyResetMFAUseCase.execute(userId: userId, code: code)
            let resetToken = response.data.resetToken
            currentState = .newPassword(userId: userId, resetToken: resetToken)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    public func resetPassword(_ newPassword: String, resetToken: String) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await resetPasswordUseCase.execute(newPassword: newPassword, resetToken: resetToken)
            if response.data.success {
                currentState = .success
            } else {
                self.error = ForgotPasswordError.passwordResetFailed
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    public func restart() {
        currentState = .email
        error = nil
    }
}

// MARK: - Forgot Password Errors

public enum ForgotPasswordError: LocalizedError {
    case invalidCode
    case passwordResetFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Código de verificación inválido"
        case .passwordResetFailed:
            return "No se pudo restablecer la contraseña"
        }
    }
}