import Foundation
import SwiftUI

// MARK: - Forgot Password Flow State

public enum ForgotPasswordFlowState {
    case email
    case verification(email: String)
    case newPassword(resetToken: String)
    case success
}

// MARK: - Forgot Password Coordinator ViewModel

@MainActor
public final class ForgotPasswordCoordinatorViewModel: ObservableObject {
    @Published public private(set) var currentState: ForgotPasswordFlowState = .email
    @Published public private(set) var isLoading = false
    @Published public var error: Error?
    
    /// Code and resend countdowns for the recovery code, from the backend. `nil`
    /// until the first email has been requested.
    @Published public private(set) var codeWindow: MFACodeWindow?
    /// When the token handed out by `verify-reset-mfa` stops being accepted. The
    /// password form is useless past this point, so the flow restarts instead of
    /// letting the user type a new password only to have it rejected.
    @Published public private(set) var resetTokenExpiresAt: Date?
    
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
            codeWindow = MFACodeWindow(
                expiresInSeconds: response.data.expiresInSeconds,
                resendCodeTimeInSeconds: response.data.resendCodeTimeInSeconds
            )
            currentState = .verification(email: email)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    public func verifyCode(_ code: String, email: String) async {
        // The backend rejects an expired code anyway; refusing it here tells the
        // user why, and points them at the resend instead of a generic failure.
        if let codeWindow, codeWindow.isCodeExpired() {
            error = ForgotPasswordError.codeExpired
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await verifyResetMFAUseCase.execute(email: email, code: code)
            let resetToken = response.data.resetToken
            resetTokenExpiresAt = Date().addingTimeInterval(
                TimeInterval(response.data.expiresInSeconds ?? MFADefaults.resetToken)
            )
            currentState = .newPassword(resetToken: resetToken)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    public func resetPassword(_ newPassword: String, resetToken: String) async {
        // Back to the start rather than a rejected request: the token is gone and
        // a new one only comes from a new emailed code.
        if let resetTokenExpiresAt, Date() >= resetTokenExpiresAt {
            restart()
            error = ForgotPasswordError.resetTokenExpired
            return
        }

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
        codeWindow = nil
        resetTokenExpiresAt = nil
    }
}

// MARK: - Forgot Password Errors

public enum ForgotPasswordError: LocalizedError {
    case invalidCode
    case passwordResetFailed
    case codeExpired
    case resetTokenExpired
    
    public var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Código de verificación inválido"
        case .passwordResetFailed:
            return "No se pudo restablecer la contraseña"
        case .codeExpired:
            return L10n.MFA.codeExpired
        case .resetTokenExpired:
            return L10n.ForgotPassword.resetTokenExpired
        }
    }
}
