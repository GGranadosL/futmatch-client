import SwiftUI
import FMDesignSystem
import Lottie
import SharedModels

/// Auth landing — the first screen for a signed-out user. Lottie hero, brand,
/// benefits, and three actions: "Continue with email" (pushes `EmailLoginView`),
/// plus the Google and Apple buttons. The email/password form lives on the pushed
/// screen; this view owns the `NavigationStack`, the shared `LoginViewModel`, and
/// the social sign-up cover.
public struct AuthLandingView: View {
    @StateObject private var viewModel: LoginViewModel
    @State private var showEmailLogin = false
    /// Set when an in-flight Apple onboarding bounces back here because its
    /// identity token expired mid-flow (see `OnboardingViewModel.scheduleCredentialExpiry`).
    @State private var showAppleSessionExpiredToast = false
    /// Explains why an account-linking attempt ended without completing.
    @State private var linkDismissedMessage: String?
    @State private var showLinkDismissedToast = false

    /// Injected country data source forwarded to the Onboarding flow.
    private let fetchCountriesUseCase: (any FetchCountriesUseCaseProtocol)?
    /// Injected dial-code data source forwarded to the Onboarding flow.
    private let fetchDialCodesUseCase: (any FetchDialCodesUseCaseProtocol)?
    /// Provider SDK wrappers, owned by the app target. A missing entry hides that
    /// provider's button.
    private let socialProviders: [AuthProvider: any SocialAuthProviding]
    /// Builds the registration use case for whichever provider needs onboarding.
    private let makeRegisterSocialUserUseCase: ((AuthProvider) -> (any RegisterSocialUserUseCaseProtocol)?)?
    /// Builds the ViewModel for the account-linking flow. Takes the provider wrapper
    /// this view already holds, so there is no optional to unwrap downstream — the
    /// request can only exist for a provider whose button was on screen.
    private let makeSocialLinkViewModel: ((SocialLinkRequest, any SocialAuthProviding) -> SocialLinkViewModel)?
    /// Draft persistence, forwarded to whichever onboarding flow this screen opens.
    private let saveOnboardingDraftUseCase: (any SaveOnboardingDraftUseCaseProtocol)?
    private let getOnboardingDraftUseCase: (any GetOnboardingDraftUseCaseProtocol)?
    private let clearOnboardingDraftUseCase: (any ClearOnboardingDraftUseCaseProtocol)?
    /// Callback when login or registration is successful
    public var onLoginSuccess: (() -> Void)?

    public init(
        fetchCountriesUseCase: (any FetchCountriesUseCaseProtocol)? = nil,
        fetchDialCodesUseCase: (any FetchDialCodesUseCaseProtocol)? = nil,
        socialProviders: [AuthProvider: any SocialAuthProviding] = [:],
        signInWithSocialUseCase: (any SignInWithSocialUseCaseProtocol)? = nil,
        makeRegisterSocialUserUseCase: ((AuthProvider) -> (any RegisterSocialUserUseCaseProtocol)?)? = nil,
        makeSocialLinkViewModel: ((SocialLinkRequest, any SocialAuthProviding) -> SocialLinkViewModel)? = nil,
        saveOnboardingDraftUseCase: (any SaveOnboardingDraftUseCaseProtocol)? = nil,
        getOnboardingDraftUseCase: (any GetOnboardingDraftUseCaseProtocol)? = nil,
        clearOnboardingDraftUseCase: (any ClearOnboardingDraftUseCaseProtocol)? = nil,
        onLoginSuccess: (() -> Void)? = nil,
        firebaseSignIn: ((String) async throws -> Void)? = nil
    ) {
        self.fetchCountriesUseCase = fetchCountriesUseCase
        self.fetchDialCodesUseCase = fetchDialCodesUseCase
        self.socialProviders = socialProviders
        self.makeRegisterSocialUserUseCase = makeRegisterSocialUserUseCase
        self.makeSocialLinkViewModel = makeSocialLinkViewModel
        self.saveOnboardingDraftUseCase = saveOnboardingDraftUseCase
        self.getOnboardingDraftUseCase = getOnboardingDraftUseCase
        self.clearOnboardingDraftUseCase = clearOnboardingDraftUseCase
        self.onLoginSuccess = onLoginSuccess
        _viewModel = StateObject(wrappedValue: LoginViewModel(
            signInWithSocialUseCase: signInWithSocialUseCase,
            socialProviders: socialProviders,
            firebaseSignIn: firebaseSignIn
        ))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AuthLandingBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        AuthLandingHero()
                        brandSection
                        benefitsSection
                        Spacer(minLength: 32)
                        actionsSection
                    }
                    .padding(.horizontal, 24)
                }

                // `/auth/{provider}/resolve` found a Futmatch account that already
                // owns this email. Adding the provider to it takes the account's
                // password and an emailed code — matching addresses alone never
                // link anything — so the flow mounts here rather than opening the
                // sign-up cover as `SIGN_UP_REQUIRED` does.
                socialLinkFlow
            }
            .background(FMColors.background)
            // Freezes the screen the instant a login succeeds — social sign-in sets
            // `isLoginSuccessful` and `RootView` swaps in Home on its next render
            // pass, which isn't instant.
            .allowsHitTesting(!viewModel.isLoginSuccessful)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showEmailLogin) {
                EmailLoginView(
                    viewModel: viewModel,
                    onLoginSuccess: onLoginSuccess,
                    fetchCountriesUseCase: fetchCountriesUseCase,
                    fetchDialCodesUseCase: fetchDialCodesUseCase,
                    saveOnboardingDraftUseCase: saveOnboardingDraftUseCase,
                    getOnboardingDraftUseCase: getOnboardingDraftUseCase,
                    clearOnboardingDraftUseCase: clearOnboardingDraftUseCase
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
            .fmToast(L10n.Login.appleSessionExpired, isPresented: $showAppleSessionExpiredToast, style: .error)
            .fmToast(linkDismissedMessage ?? "", isPresented: $showLinkDismissedToast, style: .error)
            // `/auth/{provider}/resolve` found no account for this identity, so
            // the same button that signs people in also starts the sign-up — with
            // everything the provider gave us already filled in.
            .fullScreenCover(item: $viewModel.socialSignUpAccount) { account in
                OnboardingContainerView(
                    fetchCountriesUseCase: fetchCountriesUseCase,
                    fetchDialCodesUseCase: fetchDialCodesUseCase,
                    socialAccount: account,
                    registerSocialUserUseCase: makeRegisterSocialUserUseCase?(account.provider),
                    saveOnboardingDraftUseCase: saveOnboardingDraftUseCase,
                    getOnboardingDraftUseCase: getOnboardingDraftUseCase,
                    clearOnboardingDraftUseCase: clearOnboardingDraftUseCase,
                    onRegistrationComplete: {
                        viewModel.socialSignUpAccount = nil
                        onLoginSuccess?()
                    },
                    // Apple's identity token expired before the user finished
                    // onboarding. The draft is already saved at this point — the
                    // container only sets this after `saveDraftIfNeeded()` — so
                    // dismissing here and letting the user tap Apple again is what
                    // resumes it, prefilled, via the draft matcher.
                    onRequiresReauthentication: {
                        viewModel.socialSignUpAccount = nil
                        showAppleSessionExpiredToast = true
                    }
                )
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var socialLinkFlow: some View {
        if let request = viewModel.socialLinkRequest,
           let makeSocialLinkViewModel,
           let socialAuth = socialProviders[request.account.provider] {
            SocialLinkFlowView(
                // Autoclosure: built once, on first render, not on every pass.
                viewModel: makeSocialLinkViewModel(request, socialAuth),
                // Goes through `isLoginSuccessful` rather than calling
                // `onLoginSuccess` directly, so linking gets the same treatment as
                // every other successful sign-in: the screen freezes immediately
                // while `RootView` swaps in Home on its next render pass.
                onLinked: { viewModel.isLoginSuccessful = true },
                onDismiss: { message in
                    viewModel.socialLinkRequest = nil
                    guard let message else { return }
                    linkDismissedMessage = message
                    showLinkDismissedToast = true
                }
            )
        }
    }

    /// Same logo + wordmark style as Home's header bar, centered here.
    private var brandSection: some View {
        VStack(spacing: 8) {
            FMBrandLogo(iconSize: 36, fontSize: 30)

            Text(L10n.Login.landingTagline)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.secondary)
        }
        .padding(.top, 4)
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow(L10n.Login.landingBenefitFindMatch, systemImage: "soccerball")
            benefitRow(L10n.Login.landingBenefitConnect, systemImage: "person.3.fill")
            benefitRow(L10n.Login.landingBenefitStandOut, systemImage: "star")
        }
        .padding(.top, 32)
    }

    private func benefitRow(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(FMColors.primary)
                .frame(width: 20)

            Text(text)
                .font(FMTypography.bodySmall)
                .foregroundColor(FMColors.onSurfaceVariant)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 24) {
            FMPrimaryButton(
                title: L10n.Login.continueWithEmail,
                icon: Image(systemName: "envelope.fill")
            ) {
                showEmailLogin = true
            }

            if viewModel.isGoogleAvailable {
                // One button covers both outcomes: an existing account signs
                // straight in, an unknown one opens the prefilled sign-up.
                FMGoogleSignInButton(
                    title: L10n.Login.continueWithGoogle,
                    isLoading: viewModel.isGoogleLoading,
                    isEnabled: !viewModel.isLoading && !viewModel.isAppleLoading
                ) {
                    Task {
                        await viewModel.continueWithGoogle()
                    }
                }
            }

            if viewModel.isAppleAvailable {
                FMAppleSignInButton(
                    title: L10n.Login.continueWithApple,
                    isLoading: viewModel.isAppleLoading,
                    isEnabled: !viewModel.isLoading && !viewModel.isGoogleLoading
                ) {
                    Task {
                        await viewModel.continueWithApple()
                    }
                }
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 32)
    }
}

// MARK: - Hero animation

/// Lottie hero for the landing screen. Loops continuously, but honours Reduce
/// Motion by holding on the first frame.
private struct AuthLandingHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        lottie
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .accessibilityLabel(Text(L10n.Login.landingAnimationA11y))
            .padding(.top, 40)
    }

    @ViewBuilder
    private var lottie: some View {
        let animation = LottieView(animation: .named("football_team_players", bundle: .module))
        if reduceMotion {
            animation.paused().resizable().aspectRatio(contentMode: .fit)
        } else {
            animation.playing(loopMode: .loop).resizable().aspectRatio(contentMode: .fit)
        }
    }
}

// MARK: - Preview
#Preview {
    AuthLandingView()
}
