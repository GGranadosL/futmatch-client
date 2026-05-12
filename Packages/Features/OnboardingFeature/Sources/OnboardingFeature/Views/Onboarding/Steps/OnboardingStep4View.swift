import SwiftUI
import FMDesignSystem

/// Step 4: Review & Confirm
struct OnboardingStep4View: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    private var formattedBirthDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: viewModel.birthDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            scrollContent
            bottomSection
        }
        .background(FMColors.background)
        .navigationDestination(isPresented: $viewModel.showVerification) {
            VerificationCodeView(
                viewModel: viewModel,
                email: viewModel.email,
                countdown: viewModel.resendCodeTimeInSeconds
            )
        }
    }
    
    // MARK: - Subviews
    
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                FMOnboardingHeader(
                    title: L10n.Step4.title,
                    subtitle: L10n.Step4.subtitle
                )
                .padding(.top, 24)
                
                identitySection
                personalInfoSection
                contactSection
                errorMessageView
                successMessageView
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    private var identitySection: some View {
        ReviewSection(title: L10n.Step4.identity) {
            HStack(spacing: 16) {
                FMAvatar(image: viewModel.profileImage, size: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.firstName) \(viewModel.lastName)")
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.primary)
                    
                    Text(viewModel.playerPosition.description)
                        .font(FMTypography.caption)
                        .foregroundColor(FMColors.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private var personalInfoSection: some View {
        ReviewSection(title: L10n.Step4.personalInfo) {
            VStack(spacing: 12) {
                ReviewRow(label: L10n.Step4.birthDate, value: formattedBirthDate)
                ReviewRow(label: L10n.Step1.gender, value: viewModel.gender.description)
                ReviewRow(label: L10n.Step2.country, value: viewModel.country)
            }
        }
    }
    
    private var contactSection: some View {
        ReviewSection(title: L10n.Step4.contact) {
            VStack(spacing: 12) {
                ReviewRow(label: L10n.Step2.email, value: viewModel.email)
                ReviewRow(label: L10n.Step2.phone, value: "\(viewModel.countryCode) \(viewModel.phone)")
            }
        }
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.error)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FMColors.error.opacity(0.1))
                )
        }
    }
    
    @ViewBuilder
    private var successMessageView: some View {
        if let success = viewModel.successMessage {
            Text(success)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.primary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FMColors.primary.opacity(0.1))
                )
        }
    }
    
    private var bottomSection: some View {
        VStack(spacing: 16) {
            FMPrimaryButton(
                title: L10n.Button.createAccount,
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.submitRegistration()
                }
            }
            
            termsText
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .padding(.top, 16)
        .background(FMColors.background)
    }
    
    private var termsText: some View {
        (
            Text(L10n.Terms.prefix)
                .foregroundColor(FMColors.onSurfaceVariant)
            +
            Text(L10n.Terms.termsOfService)
                .foregroundColor(FMColors.primary)
            +
            Text(L10n.Terms.and)
                .foregroundColor(FMColors.onSurfaceVariant)
            +
            Text(L10n.Terms.privacyPolicy)
                .foregroundColor(FMColors.primary)
        )
        .font(FMTypography.bodySmall)
        .multilineTextAlignment(.center)
    }
}

// MARK: - Review Section
private struct ReviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.secondary)
                
                Spacer()
                
                Button("Editar") {
                    // Navigate to edit
                }
                .font(FMTypography.captionMedium)
                .foregroundColor(FMColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FMColors.background)
            )
        }
    }
}

// MARK: - Review Row
private struct ReviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.secondary)
            
            Spacer()
            
            Text(value)
                .font(FMTypography.captionMedium)
                .foregroundColor(FMColors.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingStep4View(viewModel: OnboardingViewModel())
}
