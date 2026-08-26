import SwiftUI
import FMDesignSystem
import SharedModels

/// Email + password sign-in — the second auth screen, pushed from `AuthLandingView`
/// when the user taps "Continue with email". The social buttons deliberately live
/// only on the landing screen, not here.
///
/// Shares the `LoginViewModel` instance with `AuthLandingView` (passed in, not owned),
/// so the MFA push and the social sign-up cover keep working off the same state. The
/// error `.alert` and the `isLoginSuccessful` observer stay on the `AuthLandingView`
/// ancestor, which remains mounted while this screen is pushed.
struct EmailLoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss

    /// Forwarded to the onboarding flow opened by "Create account".
    private let fetchCountriesUseCase: (any FetchCountriesUseCaseProtocol)?
    private let fetchDialCodesUseCase: (any FetchDialCodesUseCaseProtocol)?
    private let saveOnboardingDraftUseCase: (any SaveOnboardingDraftUseCaseProtocol)?
    private let getOnboardingDraftUseCase: (any GetOnboardingDraftUseCaseProtocol)?
    private let clearOnboardingDraftUseCase: (any ClearOnboardingDraftUseCaseProtocol)?
    /// Fired on a successful email/password (or MFA) sign-in.
    var onLoginSuccess: (() -> Void)?

    @State private var showOnboarding = false
    @State private var showForgotPassword = false
    /// Driven by "change email" on the MFA screen so the user lands straight in the
    /// field they need to correct, keyboard already up.
    @FocusState private var focusEmail: Bool

    init(
        viewModel: LoginViewModel,
        onLoginSuccess: (() -> Void)? = nil,
        fetchCountriesUseCase: (any FetchCountriesUseCaseProtocol)? = nil,
        fetchDialCodesUseCase: (any FetchDialCodesUseCaseProtocol)? = nil,
        saveOnboardingDraftUseCase: (any SaveOnboardingDraftUseCaseProtocol)? = nil,
        getOnboardingDraftUseCase: (any GetOnboardingDraftUseCaseProtocol)? = nil,
        clearOnboardingDraftUseCase: (any ClearOnboardingDraftUseCaseProtocol)? = nil
    ) {
        self.viewModel = viewModel
        self.onLoginSuccess = onLoginSuccess
        self.fetchCountriesUseCase = fetchCountriesUseCase
        self.fetchDialCodesUseCase = fetchDialCodesUseCase
        self.saveOnboardingDraftUseCase = saveOnboardingDraftUseCase
        self.getOnboardingDraftUseCase = getOnboardingDraftUseCase
        self.clearOnboardingDraftUseCase = clearOnboardingDraftUseCase
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                logoSection
                formSection
                Spacer(minLength: 40)
                bottomSection
            }
        }
        .background(FMColors.background)
        .allowsHitTesting(!viewModel.isLoginSuccessful)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FMBackButton { dismiss() }
            }
        }
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
