import SwiftUI
import FMDesignSystem

/// Step 1: Personal Info
struct OnboardingStep1View: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    private var firstNameError: String? {
        guard !viewModel.firstName.isEmpty else { return nil }
        if viewModel.firstName.count > 30 {
            return L10n.Validation.maxCharacters(30)
        }
        if !viewModel.isFirstNameValid {
            return L10n.Validation.onlyLetters
        }
        return nil
    }
    
    private var lastNameError: String? {
        guard !viewModel.lastName.isEmpty else { return nil }
        if viewModel.lastName.count > 30 {
            return L10n.Validation.maxCharacters(30)
        }
        if !viewModel.isLastNameValid {
            return L10n.Validation.onlyLetters
        }
        return nil
    }
    
    private var birthDateError: String? {
        guard !viewModel.isBirthDateValid else { return nil }
        return L10n.Validation.minimumAge(18)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    FMOnboardingHeader(
                        title: L10n.Step1.title,
                        subtitle: L10n.Step1.subtitle
                    )
                    .padding(.top, 24)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        FMTextField(
                            label: L10n.Step1.firstName,
                            text: $viewModel.firstName,
                            contentType: .givenName,
                            errorMessage: firstNameError
                        )
                        
                        FMTextField(
                            label: L10n.Step1.lastName,
                            text: $viewModel.lastName,
                            contentType: .familyName,
                            errorMessage: lastNameError
                        )
                        
                        FMDateField(
                            label: L10n.Step1.dateOfBirth,
                            date: $viewModel.birthDate,
                            errorMessage: birthDateError
                        )
                        
                        FMChipGroup(
                            title: L10n.Step1.gender,
                            options: GenderOption.allCases,
                            selected: $viewModel.gender
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            // Fixed Bottom Button
            FMPrimaryButton(
                title: L10n.Button.nextStep,
                isEnabled: viewModel.isStep1Valid
            ) {
                viewModel.nextStep()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .padding(.top, 16)
            .background(FMColors.background)
        }
        .background(FMColors.background)
        .onDisappear {
            // Save draft only when leaving the step
            Task {
                await viewModel.saveDraftIfNeeded()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingStep1View(viewModel: OnboardingViewModel())
}
