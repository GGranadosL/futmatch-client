import SwiftUI
import FMDesignSystem
import SharedModels

/// Main Login View - Entry point of the app
public struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @State private var showOnboarding = false
    @State private var showForgotPassword = false
    /// Driven by "change email" on the MFA screen so the user lands straight in the
    /// field they need to correct, keyboard already up.
    @State private var focusEmail = false

    /// Injected country data source forwarded to the Onboarding flow.
    private let fetchCountriesUseCase: (any FetchCountriesUseCaseProtocol)?
    /// Injected dial-code data source forwarded to the Onboarding flow.
    private let fetchDialCodesUseCase: (any FetchDialCodesUseCaseProtocol)?
    /// Google SDK wrapper, owned by the app target. `nil` hides the Google button.
    private let googleAuth: (any GoogleAuthProviding)?
    /// Builds the Google registration use case once an account needs onboarding.
    private let makeRegisterGoogleUserUseCase: (() -> any RegisterGoogleUserUseCaseProtocol)?
    /// Draft persistence, forwarded to whichever onboarding flow this screen opens.
    private let saveOnboardingDraftUseCase: (any SaveOnboardingDraftUseCaseProtocol)?
    private let getOnboardingDraftUseCase: (any GetOnboardingDraftUseCaseProtocol)?
    private let clearOnboardingDraftUseCase: (any ClearOnboardingDraftUseCaseProtocol)?
    /// Callback when login or registration is successful
    public var onLoginSuccess: (() -> Void)?

    public init(
        fetchCountriesUseCase: (any FetchCountriesUseCaseProtocol)? = nil,
        fetchDialCodesUseCase: (any FetchDialCodesUseCaseProtocol)? = nil,
        googleAuth: (any GoogleAuthProviding)? = nil,
        signInWithGoogleUseCase: (any SignInWithGoogleUseCaseProtocol)? = nil,
        makeRegisterGoogleUserUseCase: (() -> any RegisterGoogleUserUseCaseProtocol)? = nil,
        saveOnboardingDraftUseCase: (any SaveOnboardingDraftUseCaseProtocol)? = nil,
        getOnboardingDraftUseCase: (any GetOnboardingDraftUseCaseProtocol)? = nil,
        clearOnboardingDraftUseCase: (any ClearOnboardingDraftUseCaseProtocol)? = nil,
        onLoginSuccess: (() -> Void)? = nil,
        firebaseSignIn: ((String) async throws -> Void)? = nil
    ) {
        self.fetchCountriesUseCase = fetchCountriesUseCase
        self.fetchDialCodesUseCase = fetchDialCodesUseCase
        self.googleAuth = googleAuth
        self.makeRegisterGoogleUserUseCase = makeRegisterGoogleUserUseCase
        self.saveOnboardingDraftUseCase = saveOnboardingDraftUseCase
        self.getOnboardingDraftUseCase = getOnboardingDraftUseCase
        self.clearOnboardingDraftUseCase = clearOnboardingDraftUseCase
        self.onLoginSuccess = onLoginSuccess
        _viewModel = StateObject(wrappedValue: LoginViewModel(
            signInWithGoogleUseCase: signInWithGoogleUseCase,
            googleAuth: googleAuth,
            firebaseSignIn: firebaseSignIn
        ))
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
            .background(FMColors.background)
            // Freezes the form the instant a login succeeds — email/password sets
            // `isLoginSuccessful` and lets `RootView` swap in Home on its own next
            // render pass, and that pass isn't instant. Nothing here was gated on
            // that in-between moment before ("Crear cuenta" doesn't care whether a
            // login is in flight), so a tap on it during the gap opened onboarding
            // on a `LoginView` that was about to be torn down — the cover then had
            // nothing left to be presented on and got yanked away the moment Home
            // mounted, dropping the user straight into Home mid-registration.
            .allowsHitTesting(!viewModel.isLoginSuccessful)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showForgotPassword) {
                ForgotPasswordView(coordinator: makeForgotPasswordCoordinator())
            }
            .navigationDestination(isPresented: $viewModel.showMFAVerification) {
                MFAVerificationView(
                    viewModel: viewModel,
                    onVerificationSuccess: {
                        onLoginSuccess?()
                    },
                    onChangeEmail: {
                        viewModel.cancelMFAToCorrectEmail()
                        // Focus after the pop animation, otherwise the field isn't
                        // in the hierarchy yet and the keyboard never comes up.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            focusEmail = true
                        }
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
                OnboardingContainerView(
                    fetchCountriesUseCase: fetchCountriesUseCase,
                    fetchDialCodesUseCase: fetchDialCodesUseCase,
                    saveOnboardingDraftUseCase: saveOnboardingDraftUseCase,
                    getOnboardingDraftUseCase: getOnboardingDraftUseCase,
                    clearOnboardingDraftUseCase: clearOnboardingDraftUseCase,
                    onRegistrationComplete: {
                        showOnboarding = false
                        onLoginSuccess?()
                    }
                )
            }
            // `/auth/google/resolve` found no account for this Google identity, so
            // the same button that signs people in also starts the sign-up — with
            // everything Google gave us already filled in.
            .fullScreenCover(item: $viewModel.googleSignUpAccount) { account in
                OnboardingContainerView(
                    fetchCountriesUseCase: fetchCountriesUseCase,
                    fetchDialCodesUseCase: fetchDialCodesUseCase,
                    googleAccount: account,
                    registerGoogleUserUseCase: makeRegisterGoogleUserUseCase?(),
                    saveOnboardingDraftUseCase: saveOnboardingDraftUseCase,
                    getOnboardingDraftUseCase: getOnboardingDraftUseCase,
                    clearOnboardingDraftUseCase: clearOnboardingDraftUseCase,
                    onRegistrationComplete: {
                        viewModel.googleSignUpAccount = nil
                        onLoginSuccess?()
                    }
                )
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
                .font(.interBold(size: 32))
                .tracking(1.5)
                .foregroundStyle(
                    LinearGradient(
                        colors: [FMColors.primary, FMColors.inversePrimary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
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
            .focused($focusEmail)

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
                icon: Image(systemName: "person.crop.circle.fill"),
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.isFormValid
            ) {
                Task {
                    await viewModel.login()
                }
            }

            if viewModel.isGoogleAvailable {
                // One button covers both outcomes: an existing account signs
                // straight in, an unknown one opens the prefilled sign-up.
                FMGoogleSignInButton(
                    title: L10n.Login.continueWithGoogle,
                    isLoading: viewModel.isGoogleLoading,
                    isEnabled: !viewModel.isLoading
                ) {
                    Task {
                        await viewModel.continueWithGoogle()
                    }
                }
            }

            Button {
                showOnboarding = true
            } label: {
                HStack(spacing: 4) {
                    Text(L10n.Login.noAccount)
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.secondary)

                    Text(L10n.Login.createAccount)
                        .font(FMTypography.captionMedium)
                        .foregroundColor(FMColors.primary)
                }
                .contentShape(Rectangle())
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
