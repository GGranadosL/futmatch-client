import SwiftUI
import FMDesignSystem

/// Step 1: Personal Info
struct OnboardingStep1View: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var focusFirstName = false
    @State private var focusLastName = false
    private let dateFieldAnchor = "birthDateField"
    
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
        // No error while the field is untouched (`nil`) — same convention as the name
        // fields above: an unfilled required field just disables "Next step", it doesn't
        // show red text before the user has had a chance to fill it in.
        guard let birthDate = viewModel.birthDate else { return nil }
        guard !FieldValidator.validateBirthDate(birthDate).isValid else { return nil }
        return L10n.Validation.minimumAge(FieldValidator.minimumAge)
    }

    /// Falls back to the generic copy when the provider gave no name to prefill
    /// with (always true for Apple past the first authorization) — otherwise the
    /// "confirm your details" framing would talk about a name the screen doesn't
    /// actually show.
    private var headerTitle: String {
        switch viewModel.provider {
        case .google: return L10n.Step1.googleTitle
        case .apple where !viewModel.firstName.isEmpty: return L10n.Step1.appleTitle
        default: return L10n.Step1.title
        }
    }

    private var headerSubtitle: String {
        switch viewModel.provider {
        case .google: return L10n.Step1.googleSubtitle
        case .apple where !viewModel.firstName.isEmpty: return L10n.Step1.appleSubtitle
        default: return L10n.Step1.subtitle
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Header — a social sign-up already has a verified email (and,
                    // usually, a name), so it gets copy that reflects that instead
                    // of the "let's get started" framing a from-scratch signup
                    // needs. Falls back to the generic copy when Apple didn't hand
                    // over a name this time (only the first authorization ever
                    // includes one), so the screen doesn't claim to know who this is.
                    FMOnboardingHeader(
                        title: headerTitle,
                        subtitle: headerSubtitle
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
                        .focused($focusFirstName)
                        .keyboardNavigation(
                            hasPrevious: false, hasNext: true,
                            onPrevious: {},
                            onNext: { focusLastName = true; focusFirstName = false }
                        )

                        FMTextField(
                            label: L10n.Step1.lastName,
                            text: $viewModel.lastName,
                            contentType: .familyName,
                            errorMessage: lastNameError
                        )
                        .focused($focusLastName)
                        .keyboardNavigation(
                            hasPrevious: true, hasNext: false,
                            onPrevious: { focusFirstName = true; focusLastName = false },
                            onNext: {}
                        )

                        FMDateField(
                            label: L10n.Step1.dateOfBirth,
                            optionalDate: $viewModel.birthDate,
                            placeholder: L10n.Step1.dateOfBirthPlaceholder,
                            style: .wheel,
                            range: viewModel.birthDateRange,
                            errorMessage: birthDateError,
                            onPickerVisibilityChanged: { isOpen in
                                guard isOpen else { return }
                                withAnimation {
                                    proxy.scrollTo(dateFieldAnchor, anchor: .center)
                                }
                            }
                        )
                        .id(dateFieldAnchor)

                        FMChipGroupOptional(
                            title: L10n.Step1.gender,
                            options: GenderOption.allCases,
                            selected: $viewModel.gender
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(FMColors.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FMPrimaryButton(
                    title: L10n.Button.nextStep,
                    isEnabled: viewModel.isStep1Valid
                ) {
                    viewModel.nextStep()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .background(FMColors.background)
            }
            .onDisappear {
                // Save draft only when leaving the step
                Task {
                    await viewModel.saveDraftIfNeeded()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingStep1View(viewModel: OnboardingViewModel())
}
