import SwiftUI
import FMDesignSystem

/// MFA Verification View - for login flow
struct MFAVerificationView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss
    
    var onVerificationSuccess: (() -> Void)?
    
    @State private var countdown: Int = 60
    @State private var timer: Timer?
    
    init(viewModel: LoginViewModel, onVerificationSuccess: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onVerificationSuccess = onVerificationSuccess
        self._countdown = State(initialValue: viewModel.resendCodeTimeInSeconds)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    codeInputSection
                    resendSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            
            bottomSection
        }
        .background(FMColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(FMColors.onSurface)
                }
            }
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: viewModel.isLoginSuccessful) { newValue in
            if newValue {
                onVerificationSuccess?()
            }
        }
        .alert(L10n.Login.errorTitle, isPresented: $viewModel.showError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(FMColors.primary)
            
            Text(L10n.MFA.title)
                .font(FMTypography.title)
                .foregroundColor(FMColors.onSurface)
            
            Text(L10n.MFA.subtitle)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
            
            Text(viewModel.email)
                .font(FMTypography.captionMedium)
                .foregroundColor(FMColors.primary)
        }
    }
    
    private var codeInputSection: some View {
        FMCodeInputField(
            code: $viewModel.verificationCode,
            codeLength: 6
        ) { _ in
            Task { await viewModel.verifyMFACode() }
        }
        .padding(.top, 24)
    }
    
    private var resendSection: some View {
        VStack(spacing: 8) {
            if countdown > 0 {
                Text(L10n.Verification.resendIn(countdown))
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.onSurfaceVariant)
            } else {
                Button {
                    Task {
                        await viewModel.resendMFACode()
                        countdown = viewModel.resendCodeTimeInSeconds
                        startCountdown()
                    }
                } label: {
                    Text(L10n.Verification.resend)
                        .font(FMTypography.captionMedium)
                        .foregroundColor(FMColors.primary)
                }
            }
        }
        .padding(.top, 16)
    }
    
    private var bottomSection: some View {
        FMPrimaryButton(
            title: L10n.MFA.verify,
            isLoading: viewModel.isLoading,
            isEnabled: viewModel.verificationCode.count == 6
        ) {
            Task {
                await viewModel.verifyMFACode()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .padding(.top, 16)
    }
    
    // MARK: - Helpers
    
    private func startCountdown() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MFAVerificationView(viewModel: LoginViewModel())
    }
}
