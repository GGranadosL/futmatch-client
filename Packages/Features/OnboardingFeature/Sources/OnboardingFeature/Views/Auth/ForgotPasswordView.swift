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
                case .verification(let userId, let email):
                    ForgotPasswordVerificationView(coordinator: coordinator, userId: userId, email: email)
                case .newPassword(let userId, let resetToken):
                    ForgotPasswordNewPasswordView(coordinator: coordinator, userId: userId, resetToken: resetToken)
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
        .hideKeyboardOnTap()
    }
}

// MARK: - Verification Code View

struct ForgotPasswordVerificationView: View {
    @ObservedObject var coordinator: ForgotPasswordCoordinatorViewModel
    let userId: String
    let email: String
    @State private var code = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer?
    
    private var isCodeValid: Bool {
        code.count == 6
    }
    
    private var canResendCode: Bool {
        timeRemaining == 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 60))
                        .foregroundColor(FMColors.primary)
                    
                    Text(L10n.ForgotPassword.verificationTitle)
                        .font(FMTypography.title)
                        .foregroundColor(FMColors.primary)
                    
                    Text(L10n.ForgotPassword.verificationSubtitle)
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 40)
                .padding(.horizontal, 24)
                
                // Code Input
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(FMColors.primary, lineWidth: 1)
                            )
                            .overlay(
                                Text(getDigit(at: index))
                                    .font(FMTypography.title2)
                                    .foregroundColor(FMColors.primary)
                            )
                            .onTapGesture {
                                isTextFieldFocused = true
                            }
                    }
                }
                .padding(.horizontal, 24)
                .onTapGesture {
                    isTextFieldFocused = true
                }
                
                // Hidden TextField for code input
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isTextFieldFocused)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .onChange(of: code) { newValue in
                        // Only allow numbers
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            code = filtered
                        }
                        if code.count > 6 {
                            code = String(code.prefix(6))
                        }
                    }
                
                Spacer(minLength: 24)
                
                // Timer and Resend Section
                VStack(spacing: 12) {
                    if canResendCode {
                        Button(L10n.ForgotPassword.resendCode) {
                            Task {
                                await coordinator.sendForgotPasswordEmail(email)
                                startTimer()
                            }
                        }
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.primary)
                    } else {
                        Text(String(format: L10n.ForgotPassword.resendTimer, timeRemaining))
                            .font(FMTypography.caption)
                            .foregroundColor(FMColors.secondary)
                    }
                }
                .padding(.bottom, 40)
                
                // Confirm Button
                FMPrimaryButton(
                    title: L10n.ForgotPassword.confirmButton,
                    isLoading: coordinator.isLoading,
                    isEnabled: isCodeValid
                ) {
                    Task {
                        await coordinator.verifyCode(code, userId: userId)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .hideKeyboardOnTap()
        .onAppear {
            // Auto-focus the text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
            // Start timer
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timeRemaining = coordinator.resendCodeTimeInSeconds
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func getDigit(at index: Int) -> String {
        if index < code.count {
            let digitIndex = code.index(code.startIndex, offsetBy: index)
            return String(code[digitIndex])
        }
        return ""
    }
}

// MARK: - New Password View

struct ForgotPasswordNewPasswordView: View {
    @ObservedObject var coordinator: ForgotPasswordCoordinatorViewModel
    let userId: String
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
        .hideKeyboardOnTap()
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
