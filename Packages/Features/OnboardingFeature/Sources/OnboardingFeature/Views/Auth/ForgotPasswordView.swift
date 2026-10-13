import SwiftUI
import Lottie
import FMDesignSystem

/// Forgot Password Flow Container View
public struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator: ForgotPasswordCoordinatorViewModel
    
    public init(coordinator: ForgotPasswordCoordinatorViewModel) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                switch coordinator.currentState {
                case .email:
                    ForgotPasswordEmailView(coordinator: coordinator)
                case .verification(let email):
                    ForgotPasswordVerificationView(coordinator: coordinator, email: email)
                case .newPassword(let resetToken):
                    ForgotPasswordNewPasswordView(coordinator: coordinator, resetToken: resetToken)
                case .success:
                    ForgotPasswordSuccessView(coordinator: coordinator)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.ForgotPassword.cancel) {
                        dismiss()
                    }
                    .foregroundColor(FMColors.primary)
                }
            }
        }
        .alert(L10n.Login.errorTitle, isPresented: .constant(coordinator.error != nil)) {
            Button(L10n.Common.ok) {
                coordinator.error = nil
            }
        } message: {
            Text(coordinator.error?.localizedDescription ?? "")
        }
    }
}

// MARK: - Email Input View

struct ForgotPasswordEmailView: View {
    @ObservedObject var coordinator: ForgotPasswordCoordinatorViewModel
    @State private var email = ""
    
    private var isEmailValid: Bool {
        email.contains("@") && email.contains(".")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 60))
                        .foregroundColor(FMColors.primary)
                    
                    Text(L10n.ForgotPassword.title)
                        .font(FMTypography.title)
                        .foregroundColor(FMColors.primary)
                    
                    Text(L10n.ForgotPassword.subtitle)
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 40)
                .padding(.horizontal, 24)
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.ForgotPassword.emailLabel)
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.secondary)
                    
                    FMTextField(
                        label: "",
                        text: $email,
                        keyboardType: .emailAddress,
                        contentType: .emailAddress
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
                
                // Send Button
                FMPrimaryButton(
                    title: L10n.ForgotPassword.sendButton,
                    isLoading: coordinator.isLoading,
                    isEnabled: isEmailValid
                ) {
                    Task {
                        await coordinator.sendForgotPasswordEmail(email)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Verification Code View

/// Password-recovery code — a thin wrapper over `MFACodeEntryView`.
///
/// Previously this screen hand-rolled its own six-digit boxes over a hidden
/// `TextField`, duplicating `FMCodeInputField`, and drove them from a counter that
/// drifted whenever the app was backgrounded.
struct ForgotPasswordVerificationView: View {
    @ObservedObject var coordinator: ForgotPasswordCoordinatorViewModel
    let email: String
    @State private var code = ""

    var body: some View {
        MFACodeEntryView(
            iconSystemName: "envelope.badge",
            title: L10n.ForgotPassword.verificationTitle,
            subtitle: L10n.ForgotPassword.verificationSubtitle,
            email: email,
            code: $code,
            isLoading: coordinator.isLoading,
            verifyButtonTitle: L10n.ForgotPassword.confirmButton,
            window: coordinator.codeWindow,
            onVerify: {
                Task { await coordinator.verifyCode(code, email: email) }
            },
            onResend: {
                Task {
                    await coordinator.sendForgotPasswordEmail(email)
                    code = ""
                }
            }
        )
    }
}

// MARK: - New Password View

struct ForgotPasswordNewPasswordView: View {
    @ObservedObject var coordinator: ForgotPasswordCoordinatorViewModel
    let resetToken: String
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    private var isPasswordValid: Bool {
        newPassword.count >= 8 && newPassword == confirmPassword && FieldValidator.validatePassword(newPassword).isValid
    }
    
    private var passwordValidationErrors: [String] {
        return FieldValidator.getPasswordErrors(newPassword).map { "• " + $0 }
    }
    
    private var passwordErrorMessage: String? {
        guard !newPassword.isEmpty else { return nil }
        let errors = passwordValidationErrors
        guard !errors.isEmpty else { return nil }
        return errors.joined(separator: "\n")
    }
    
    private var confirmPasswordErrorMessage: String? {
        guard !confirmPassword.isEmpty && !newPassword.isEmpty else { return nil }
        guard newPassword != confirmPassword else { return nil }
        return L10n.Validation.passwordsDoNotMatch
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(FMColors.primary)
                    
                    Text(L10n.ForgotPassword.newPasswordTitle)
                        .font(FMTypography.title)
                        .foregroundColor(FMColors.primary)
                    
                    Text(L10n.ForgotPassword.newPasswordSubtitle)
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 40)
                .padding(.horizontal, 24)
                
                // Password Fields
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.ForgotPassword.newPasswordLabel)
                            .font(FMTypography.caption)
                            .foregroundColor(FMColors.secondary)
                        
                        FMSecureField(
                            label: "",
                            text: $newPassword,
                            errorMessage: passwordErrorMessage
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.ForgotPassword.confirmPasswordLabel)
                            .font(FMTypography.caption)
                            .foregroundColor(FMColors.secondary)
                        
                        FMSecureField(
                            label: "",
                            text: $confirmPassword,
                            errorMessage: confirmPasswordErrorMessage
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
                
                // Reset Button
                FMPrimaryButton(
                    title: L10n.ForgotPassword.resetButton,
                    isLoading: coordinator.isLoading,
                    isEnabled: isPasswordValid
                ) {
                    Task {
                        await coordinator.resetPassword(newPassword, resetToken: resetToken)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Success View

struct ForgotPasswordSuccessView: View {
    @ObservedObject var coordinator: ForgotPasswordCoordinatorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var animationName: String {
        colorScheme == .dark ? "success_dark" : "success"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            LottieView(animation: .named(animationName, bundle: .module))
                .playing(loopMode: .playOnce)
                .resizable()
                .frame(width: 220, height: 220)
                .padding(.bottom, 16)
            
            Text(L10n.ForgotPassword.successCompleteTitle)
                .font(FMTypography.title)
                .foregroundColor(FMColors.primary)
                .padding(.bottom, 8)
            
            Text(L10n.ForgotPassword.successCompleteMessage)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            
            Spacer()
            
            // Done Button
            FMPrimaryButton(
                title: L10n.ForgotPassword.doneButton,
                isLoading: false,
                isEnabled: true
            ) {
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
