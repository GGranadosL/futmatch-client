import SwiftUI
import FMDesignSystem
import SharedModels

/// Navigation destinations for onboarding flow
enum OnboardingDestination: Hashable {
    case verification
}

/// Main Onboarding Flow Container
public struct OnboardingContainerView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationPath = NavigationPath()
    /// Shown as a `fullScreenCover` after the email is verified successfully.
    @State private var showRegistrationSuccess = false

    /// Callback when registration and verification are complete
    public var onRegistrationComplete: (() -> Void)?
    /// Called when the social credential (Apple only) expired mid-onboarding.
    /// The draft is already saved by the time this fires — the presenter should
    /// dismiss this view and let the user tap the provider button again.
    public var onRequiresReauthentication: (() -> Void)?

    /// - Parameters:
    ///   - fetchCountriesUseCase: Country data source. Defaults to `FallbackCountryRepository`.
    ///   - fetchDialCodesUseCase: Dial-code data source. Defaults to `FallbackDialCodeRepository`.
    ///   - socialAccount: set when the flow was started from "Continue with Google"
    ///     or "Continue with Apple". Prefills what the provider gave us, drops the
    ///     password field, and finishes through `/auth/{provider}/register`
    ///     instead of the email-code flow.
    ///   - registerSocialUserUseCase: required whenever `socialAccount` is set.
    ///   - saveOnboardingDraftUseCase: draft auto-save. Passing `nil` disables
    ///     draft persistence entirely, which is what previews and tests want.
    ///   - getOnboardingDraftUseCase: draft restore, matched to this flow's identity.
    ///   - clearOnboardingDraftUseCase: draft cleanup after a successful sign-up.
    ///   - onRegistrationComplete: Called after successful registration + email verification.
    ///   - onRequiresReauthentication: Called when the social credential expired.
    public init(
        fetchCountriesUseCase: (any FetchCountriesUseCaseProtocol)? = nil,
        fetchDialCodesUseCase: (any FetchDialCodesUseCaseProtocol)? = nil,
        socialAccount: SocialAccount? = nil,
        registerSocialUserUseCase: (any RegisterSocialUserUseCaseProtocol)? = nil,
        saveOnboardingDraftUseCase: (any SaveOnboardingDraftUseCaseProtocol)? = nil,
        getOnboardingDraftUseCase: (any GetOnboardingDraftUseCaseProtocol)? = nil,
        clearOnboardingDraftUseCase: (any ClearOnboardingDraftUseCaseProtocol)? = nil,
        onRegistrationComplete: (() -> Void)? = nil,
        onRequiresReauthentication: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(
            registerSocialUserUseCase: registerSocialUserUseCase,
            socialAccount: socialAccount,
            saveOnboardingDraftUseCase: saveOnboardingDraftUseCase,
            getOnboardingDraftUseCase: getOnboardingDraftUseCase,
            clearOnboardingDraftUseCase: clearOnboardingDraftUseCase,
            fetchCountriesUseCase: fetchCountriesUseCase,
            fetchDialCodesUseCase: fetchDialCodesUseCase
        ))
        self.onRegistrationComplete = onRegistrationComplete
        self.onRequiresReauthentication = onRequiresReauthentication
    }
    
    public var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Progress Bar - pegada al top
                FMProgressBar(currentStep: viewModel.currentStep, totalSteps: 4)
                    .padding(.horizontal, 24)
                
                // Content - Sin gestos de swipe
                Group {
                    switch viewModel.currentStep {
                    case 1:
                        OnboardingStep1View(viewModel: viewModel)
                    case 2:
                        OnboardingStep2View(viewModel: viewModel)
                    case 3:
                        OnboardingStep3View(viewModel: viewModel)
                    case 4:
                        OnboardingStep4View(viewModel: viewModel)
                    default:
                        OnboardingStep1View(viewModel: viewModel)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            }
            .background(FMColors.background.ignoresSafeArea())
            .navigationTitle(L10n.stepCounter(viewModel.currentStep, 4))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    FMBackButton(action: goToPreviousStep)
                }
            }
            // `.navigationBarBackButtonHidden(true)` above also disables iOS's native
            // edge-swipe-to-go-back, so it's restored manually here.
            .edgeSwipeToGoBack(action: goToPreviousStep)
            .navigationDestination(for: OnboardingDestination.self) { destination in
                switch destination {
                case .verification:
                    VerificationCodeView(
                        viewModel: viewModel,
                        email: viewModel.email,
                        countdown: viewModel.resendCodeTimeInSeconds
                    )
                }
            }
        }
        .onChange(of: viewModel.showVerification) { shouldShow in
            if shouldShow {
                navigationPath.append(OnboardingDestination.verification)
                viewModel.showVerification = false // Reset para permitir volver a navegar
            }
        }
        .onChange(of: viewModel.isVerificationComplete) { isComplete in
            if isComplete {
                // Show the success animation first; the CTA inside it triggers onRegistrationComplete.
                showRegistrationSuccess = true
            }
        }
        .fullScreenCover(isPresented: $showRegistrationSuccess) {
            RegistrationSuccessView(
                viewModel: viewModel
            ) {
                showRegistrationSuccess = false
                onRegistrationComplete?()
            }
        }
        .onChange(of: viewModel.requiresReauthentication) { requires in
            if requires {
                onRequiresReauthentication?()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            // `Task.sleep` isn't reliable across suspension, and this also covers
            // the case where the app was killed and relaunched mid-onboarding —
            // there's no in-memory expiry task to have scheduled in the first place.
            if newPhase == .active {
                viewModel.checkCredentialExpiry()
            }
        }
    }

    /// Shared by the back button and the edge-swipe gesture.
    private func goToPreviousStep() {
        if viewModel.currentStep > 1 {
            viewModel.previousStep()
        } else {
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        OnboardingContainerView()
    }
}
