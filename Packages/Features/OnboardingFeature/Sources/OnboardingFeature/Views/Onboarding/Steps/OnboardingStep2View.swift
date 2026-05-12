import SwiftUI
import FMDesignSystem

/// Step 2: Contact & Account
struct OnboardingStep2View: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var activeDropdownId: String? = nil
    
    // Country code options
    private let countryCodeOptions = [
        "+52",  // México
        "+1",   // USA/Canadá
        "+54",  // Argentina
        "+55",  // Brasil
        "+56",  // Chile
        "+57",  // Colombia
        "+34",  // España
        "+33"   // Francia
    ]
    
    // Country options
    private let countryOptions = [
        "México",
        "USA",
        "Canadá",
        "Argentina",
        "Brasil",
        "Chile",
        "Colombia",
        "España",
        "Francia"
    ]
    
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
        VStack(spacing: 0) {
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
                        
                        VStack(alignment: .leading, spacing: 4) {
                            FMTextField(
                                label: L10n.Step2.password,
                                text: $viewModel.password,
                                isSecure: true,
                                errorMessage: passwordErrorMessage
                            )
                        }
                        
                        // Phone with country code dropdown
                        HStack(alignment: .top, spacing: 12) {
                            FMDropdownField(
                                label: L10n.Step2.countryCode,
                                dropdownId: "countryCode",
                                selectedValue: $viewModel.countryCode,
                                activeDropdownId: $activeDropdownId,
                                options: countryCodeOptions
                            )
                            .frame(width: 100)
                            .zIndex(2)
                            
                            FMTextField(
                                label: L10n.Step2.phone,
                                text: $viewModel.phone,
                                keyboardType: .phonePad,
                                contentType: .telephoneNumber,
                                errorMessage: phoneErrorMessage
                            )
                        }
                        .zIndex(2)
                        
                        // Country dropdown
                        FMDropdownField(
                            label: L10n.Step2.country,
                            dropdownId: "country",
                            selectedValue: $viewModel.country,
                            activeDropdownId: $activeDropdownId,
                            options: countryOptions
                        )
                        .zIndex(1)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            // Fixed Bottom Button
            FMPrimaryButton(
                title: L10n.Button.nextStep,
                isEnabled: viewModel.isStep2Valid
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
    OnboardingStep2View(viewModel: OnboardingViewModel())
}
