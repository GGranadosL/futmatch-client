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
    @State private var navigationPath = NavigationPath()
    /// Shown as a `fullScreenCover` after the email is verified successfully.
    @State private var showRegistrationSuccess = false

    /// Callback when registration and verification are complete
    public var onRegistrationComplete: (() -> Void)?

    /// - Parameters:
    ///   - fetchCountriesUseCase: Country data source. Defaults to `FallbackCountryRepository`.
    ///   - fetchDialCodesUseCase: Dial-code data source. Defaults to `FallbackDialCodeRepository`.
    ///   - onRegistrationComplete: Called after successful registration + email verification.
    public init(
        fetchCountriesUseCase: (any FetchCountriesUseCaseProtocol)? = nil,
        fetchDialCodesUseCase: (any FetchDialCodesUseCaseProtocol)? = nil,
        onRegistrationComplete: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(
            fetchCountriesUseCase: fetchCountriesUseCase,
            fetchDialCodesUseCase: fetchDialCodesUseCase
        ))
        self.onRegistrationComplete = onRegistrationComplete
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
            .hideKeyboardOnTap()
            .background(FMColors.background.ignoresSafeArea())
            .navigationTitle(L10n.stepCounter(viewModel.currentStep, 4))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if viewModel.currentStep > 1 {
                            viewModel.previousStep()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(FMColors.primary)
                    }
                }
            }
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
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        OnboardingContainerView()
    }
}
