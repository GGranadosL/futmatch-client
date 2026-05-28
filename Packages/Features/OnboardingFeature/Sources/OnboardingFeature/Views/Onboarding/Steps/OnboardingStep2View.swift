import SwiftUI
import FMDesignSystem
import SharedModels

// Retroactive conformances so Country and DialCode can be used directly as dropdown options.
// FMDropdownOption requires Identifiable, Hashable, and displayName — all already satisfied.
extension Country: @retroactive FMDropdownOption {}
extension DialCode: @retroactive FMDropdownOption {}

/// Step 2: Contact & Account
struct OnboardingStep2View: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var activeDropdownId: String? = nil
    @State private var focusEmail = false
    @State private var focusPassword = false
    @State private var focusPhone = false

    /// Dial-code list: Remote Config data once loaded, fallback otherwise.
    /// Each entry shows "🇲🇽 +52" via `DialCode.displayName`.
    private var dialCodeList: [DialCode] {
        viewModel.dialCodes.isEmpty ? DialCode.fallback : viewModel.dialCodes
    }

    /// Bridges `viewModel.countryCode` (stores just the dial string, e.g. "+52")
    /// with the typed `DialCode?` generic dropdown.
    private var dialCodeOptionBinding: Binding<DialCode?> {
        Binding(
            get: {
                // Match on iso first (unique), fall back to first dial-code match
                // for the initial "+52" pre-fill where no iso is stored yet.
                dialCodeList.first { $0.iso == viewModel.selectedDialCodeISO }
                    ?? dialCodeList.first { $0.dialCode == viewModel.countryCode }
            },
            set: { dialCode in
                viewModel.countryCode = dialCode?.dialCode ?? ""
                viewModel.selectedDialCodeISO = dialCode?.iso ?? ""
            }
        )
    }

    /// Active list: Remote Config data once loaded, fallback otherwise.
    /// Both sources already carry flag + name via `Country.displayName`.
    private var countryList: [Country] {
        viewModel.countries.isEmpty ? Country.fallback : viewModel.countries
    }

    /// Bridges the `String`-based `viewModel.country` (stores name, e.g. "México")
    /// and `viewModel.countryISO` (stores ISO code, e.g. "MX") with the `Country?`-typed dropdown.
    private var countryOptionBinding: Binding<Country?> {
        Binding(
            get: {
                countryList.first {
                    $0.name == viewModel.country || $0.displayName == viewModel.country
                }
            },
            set: { country in
                viewModel.country = country?.name ?? ""
                viewModel.countryISO = country?.iso ?? ""
            }
        )
    }
    
    private var passwordErrorMessage: String? {
        guard !viewModel.password.isEmpty else { return nil }
        let errors = viewModel.passwordValidationErrors
        guard !errors.isEmpty else { return nil }
        return errors.joined(separator: "\n")
    }
    
    private var phoneErrorMessage: String? {
        // Solo mostrar error si tiene dígitos pero son muy pocos o demasiados
        let digitsOnly = viewModel.phone.filter { $0.isNumber }
        guard digitsOnly.count > 0 else { return nil }
        
        // Si tiene menos de 7 dígitos, no mostrar error aún (está escribiendo)
        // Si tiene más de 15 dígitos, mostrar error
        if digitsOnly.count > 15 {
            return L10n.Validation.invalidPhone
        }
        
        // No mostrar error mientras escribe (7+ dígitos es válido)
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                FMOnboardingHeader(
                    title: L10n.Step2.title,
                    subtitle: L10n.Step2.subtitle
                )
                .padding(.top, 24)

                // Form Fields
                VStack(spacing: 20) {
                    FMTextField(
                        label: L10n.Step2.email,
                        text: $viewModel.email,
                        keyboardType: .emailAddress,
                        errorMessage: !viewModel.email.isEmpty && !viewModel.isEmailValid ? L10n.Step2.invalidEmail : nil
                    )
                    .focused($focusEmail)
                    .keyboardNavigation(
                        hasPrevious: false, hasNext: true,
                        onPrevious: {},
                        onNext: { focusPassword = true; focusEmail = false }
                    )

                    FMTextField(
                        label: L10n.Step2.password,
                        text: $viewModel.password,
                        isSecure: true,
                        errorMessage: passwordErrorMessage
                    )
                    .focused($focusPassword)
                    .keyboardNavigation(
                        hasPrevious: true, hasNext: true,
                        onPrevious: { focusEmail = true; focusPassword = false },
                        onNext: { focusPhone = true; focusPassword = false }
                    )

                    // Phone with country code dropdown
                    HStack(alignment: .top, spacing: 12) {
                        FMDropdownField(
                            label: L10n.Step2.countryCode,
                            dropdownId: "countryCode",
                            selectedOption: dialCodeOptionBinding,
                            activeDropdownId: $activeDropdownId,
                            options: dialCodeList
                        )
                        // 115 pt fits "🇲🇽 +52" through "🇪🇨 +593" + chevron + padding
                        .frame(width: 115)
                        .zIndex(2)

                        FMTextField(
                            label: L10n.Step2.phone,
                            text: $viewModel.phone,
                            keyboardType: .phonePad,
                            contentType: .telephoneNumber,
                            errorMessage: phoneErrorMessage
                        )
                        .focused($focusPhone)
                        .keyboardNavigation(
                            hasPrevious: true, hasNext: false,
                            onPrevious: { focusPassword = true; focusPhone = false },
                            onNext: {}
                        )
                    }
                    .zIndex(2)

                    // Country dropdown — opens upward so it is never obscured by the
                    // bottom button. List from Remote Config (flag + name via Country.displayName).
                    FMDropdownField(
                        label: L10n.Step2.country,
                        dropdownId: "country",
                        selectedOption: countryOptionBinding,
                        activeDropdownId: $activeDropdownId,
                        options: countryList,
                        opensUpward: true
                    )
                    .zIndex(1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(FMColors.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FMPrimaryButton(
                title: L10n.Button.nextStep,
                isEnabled: viewModel.isStep2Valid
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

// MARK: - Preview
#Preview {
    OnboardingStep2View(viewModel: OnboardingViewModel())
}
