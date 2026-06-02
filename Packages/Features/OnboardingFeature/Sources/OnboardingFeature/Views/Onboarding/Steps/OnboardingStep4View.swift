import SwiftUI
import FMDesignSystem

/// Step 4: Review & Confirm
struct OnboardingStep4View: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    private func flagAndName(for iso: String) -> String {
        let upper = iso.uppercased()
        let flag = upper.unicodeScalars.compactMap { Unicode.Scalar($0.value + 127397) }
            .map(String.init).joined()
        let name = Locale.current.localizedString(forRegionCode: iso) ?? iso
        return flag.isEmpty ? name : "\(flag) \(name)"
    }

    private var formattedBirthDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: viewModel.birthDate)
    }
    
    var body: some View {
        scrollContent
            .background(FMColors.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomSection
            }
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
        ReviewSection(title: L10n.Step4.identity, onEdit: { viewModel.goToStep(1) }) {
            HStack(spacing: 16) {
                FMAvatar(image: viewModel.profileImage, size: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(viewModel.firstName) \(viewModel.lastName)")
                        .font(FMTypography.bodyMedium)
                        .foregroundColor(FMColors.onSurface)

                    if let position = viewModel.playerPosition {
                        HStack(spacing: 4) {
                            Image(systemName: "soccerball")
                                .font(.system(size: 11))
                                .foregroundColor(FMColors.onSurfaceVariant)
                            Text(position.description)
                                .font(FMTypography.labelSmall)
                                .foregroundColor(FMColors.onSurfaceVariant)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(FMColors.surfaceContainer)
                        .clipShape(Capsule())
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var personalInfoSection: some View {
        ReviewSection(title: L10n.Step4.personalInfo, onEdit: { viewModel.goToStep(1) }) {
            ReviewRow(label: L10n.Step4.birthDate, value: formattedBirthDate)
            ReviewRow(label: L10n.Step1.gender, value: viewModel.gender?.description ?? "—")
            ReviewRow(label: L10n.Step2.country, value: flagAndName(for: viewModel.countryISO), isLast: true)
        }
    }

    private var contactSection: some View {
        ReviewSection(title: L10n.Step4.contact, onEdit: { viewModel.goToStep(2) }) {
            ReviewRow(label: L10n.Step2.email, value: viewModel.email)
            ReviewRow(label: L10n.Step2.phone, value: "\(viewModel.countryCode) \(viewModel.phone)", isLast: true)
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
        .padding(.top, 16)
        .padding(.bottom, 16)
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
    let onEdit: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(FMTypography.labelMedium)
                    .foregroundColor(FMColors.onSurfaceVariant)

                Spacer()

                Button("Editar", action: onEdit)
                    .font(FMTypography.labelMedium)
                    .foregroundColor(FMColors.primary)
            }

            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMColors.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMColors.outlineVariant, lineWidth: 1)
            )
        }
    }
}

// MARK: - Review Row
private struct ReviewRow: View {
    let label: String
    let value: String
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurfaceVariant)

                Spacer()

                Text(value)
                    .font(FMTypography.bodySmall)
                    .foregroundColor(FMColors.onSurface)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingStep4View(viewModel: OnboardingViewModel())
}
