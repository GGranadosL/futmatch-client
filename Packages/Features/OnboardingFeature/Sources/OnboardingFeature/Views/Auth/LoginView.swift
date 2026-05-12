import SwiftUI
import FMDesignSystem

/// Main Login View - Entry point of the app
public struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showOnboarding = false
    @State private var showForgotPassword = false
    
    /// Callback when login or registration is successful
    public var onLoginSuccess: (() -> Void)?
    
    public init(onLoginSuccess: (() -> Void)? = nil) {
        self.onLoginSuccess = onLoginSuccess
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    logoSection
                    formSection
                    Spacer(minLength: 40)
                    bottomSection
                }
            }
            .hideKeyboardOnTap()
            .background(FMColors.background)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showForgotPassword) {
                ForgotPasswordView(coordinator: makeForgotPasswordCoordinator())
            }
            .navigationDestination(isPresented: $viewModel.showMFAVerification) {
                MFAVerificationView(
                    viewModel: viewModel,
                    onVerificationSuccess: {
                        onLoginSuccess?()
                    }
                )
            }
            .onChange(of: viewModel.isLoginSuccessful) { newValue in
                if newValue {
                    onLoginSuccess?()
                }
            }
            .alert(viewModel.errorTitle, isPresented: $viewModel.showError) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingContainerView(onRegistrationComplete: {
                    showOnboarding = false
                    onLoginSuccess?()
                })
            }
        }
    }
    
    // MARK: - Subviews
    
    private var logoSection: some View {
        VStack(spacing: 8) {
            Image("logo_futmatch", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 61, height: 73)
            
            Text("FutMatch")
                .font(FMTypography.title)
                .foregroundColor(FMColors.primary)
            
            Text(L10n.Login.title)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.secondary)
        }
        .padding(.top, 60)
        .padding(.bottom, 40)
    }
    
    private var formSection: some View {
        VStack(spacing: 20) {
            FMTextField(
                label: L10n.Login.email,
                text: $viewModel.email,
                keyboardType: .emailAddress
            )
            
            FMTextField(
                label: L10n.Login.password,
                text: $viewModel.password,
                isSecure: true
            )
            
            HStack {
                Spacer()
                Button {
                    showForgotPassword = true
                } label: {
                    Text(L10n.Login.forgotPassword)
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.primary)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var bottomSection: some View {
        VStack(spacing: 24) {
            FMPrimaryButton(
                title: L10n.Login.button,
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.isFormValid
            ) {
                Task {
                    await viewModel.login()
                }
            }
            
            HStack(spacing: 4) {
                Text(L10n.Login.noAccount)
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.secondary)
                
                Button {
                    showOnboarding = true
                } label: {
                    Text(L10n.Login.createAccount)
                        .font(FMTypography.captionMedium)
                        .foregroundColor(FMColors.primary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    // MARK: - Helper Methods
    
    private func makeForgotPasswordCoordinator() -> ForgotPasswordCoordinatorViewModel {
        let authService = AuthService()
        let forgotPasswordUseCase = ForgotPasswordUseCase(authService: authService)
        let verifyResetMFAUseCase = VerifyResetMFAUseCase(authService: authService)
        let resetPasswordUseCase = ResetPasswordUseCase(authService: authService)
        
        return ForgotPasswordCoordinatorViewModel(
            forgotPasswordUseCase: forgotPasswordUseCase,
            verifyResetMFAUseCase: verifyResetMFAUseCase,
            resetPasswordUseCase: resetPasswordUseCase
        )
    }
}

// MARK: - Preview
#Preview {
    LoginView()
}
