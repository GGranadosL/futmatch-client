import SwiftUI
import FMDesignSystem

/// Email Verification View with 6-digit code input
struct VerificationCodeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var code: String = ""
    @State private var timeRemaining: Int
    @State private var canResend: Bool = false
    @State private var timer: Timer?
    @State private var shakeOffset: CGFloat = 0
    
    let email: String
    let initialCountdown: Int
    
    init(viewModel: OnboardingViewModel, email: String, countdown: Int = 60) {
        self.viewModel = viewModel
        self.email = email
        self.initialCountdown = countdown
        self._timeRemaining = State(initialValue: countdown)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text(L10n.Verification.title)
                            .font(FMTypography.title)
                            .foregroundColor(FMColors.primary)
                        
                        VStack(spacing: 4) {
                            Text(L10n.Verification.subtitle)
                                .font(FMTypography.caption)
                                .foregroundColor(FMColors.secondary)
                            
                            Text(email)
                                .font(FMTypography.captionMedium)
                                .foregroundColor(FMColors.primary)
                            
                            Text(L10n.Verification.instruction)
                                .font(FMTypography.caption)
                                .foregroundColor(FMColors.secondary)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Error banner — above the code input so keyboard never hides it
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(FMColors.error)
                            Text(error)
                                .font(FMTypography.caption)
                                .foregroundColor(FMColors.error)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FMColors.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Code Input
                    FMCodeInputField(code: $code) { completedCode in
                        verifyCode(completedCode)
                    }
                    .offset(x: shakeOffset)
                    .padding(.vertical, 24)
                }
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
            }
            .hideKeyboardOnTap()
            
            // Bottom Section
            VStack(spacing: 16) {
                // Confirm Button
                FMPrimaryButton(
                    title: L10n.Verification.confirm,
                    isLoading: viewModel.isLoading,
                    isEnabled: code.count == 6
                ) {
                    verifyCode(code)
                }
                
                // Resend Section
                if canResend {
                    VStack(spacing: 4) {
                        Text(L10n.Verification.didntReceive)
                            .font(FMTypography.caption)
                            .foregroundColor(FMColors.secondary)
                        
                        Button {
                            resendCode()
                        } label: {
                            Text(L10n.Verification.resend)
                                .font(FMTypography.captionMedium)
                                .foregroundColor(FMColors.primary)
                        }
                    }
                } else {
                    Text(L10n.Verification.resendIn(timeRemaining))
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .padding(.top, 16)
        }
        .background(FMColors.background)
        .navigationTitle(L10n.Verification.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(FMColors.primary)
                }
            }
        }
        .onChange(of: code) { newValue in
            // Only dismiss error when the user starts typing (not when we clear programmatically)
            if viewModel.errorMessage != nil, !newValue.isEmpty {
                viewModel.errorMessage = nil
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        canResend = false
        timeRemaining = initialCountdown
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                canResend = true
                timer?.invalidate()
            }
        }
    }
    
    // MARK: - Actions
    
    private func verifyCode(_ codeToVerify: String) {
        Task {
            await viewModel.verifyCode(codeToVerify)
            if viewModel.errorMessage != nil {
                // Clear fields and shake so user can re-enter immediately
                code = ""
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) {
                    shakeOffset = -12
                }
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 10).delay(0.1)) {
                    shakeOffset = 0
                }
            }
        }
    }
    
    private func resendCode() {
        Task {
            await viewModel.resendVerificationCode()
            startTimer()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        VerificationCodeView(
            viewModel: OnboardingViewModel(),
            email: "diego.beltran@mexample.com",
            countdown: 60
        )
    }
}
