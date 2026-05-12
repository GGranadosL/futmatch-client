import SwiftUI
import FMDesignSystem

/// Navigation destinations for onboarding flow
enum OnboardingDestination: Hashable {
    case verification
}

/// Main Onboarding Flow Container
public struct OnboardingContainerView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()
    
    /// Callback when registration and verification are complete
    public var onRegistrationComplete: (() -> Void)?
    
    public init(onRegistrationComplete: (() -> Void)? = nil) {
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
