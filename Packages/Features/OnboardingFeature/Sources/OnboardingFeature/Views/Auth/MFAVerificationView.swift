import SwiftUI
import FMDesignSystem

/// Login MFA — a thin wrapper over `MFACodeEntryView`.
///
/// Everything about counting down, expiry and resending lives in that component;
/// what's specific to login is the copy, the email chip and the "wrong email?"
/// escape hatch below it.
struct MFAVerificationView: View {
    @ObservedObject var viewModel: LoginViewModel

    var onVerificationSuccess: (() -> Void)?
    /// Pops back to the login form with the email field focused. The resend endpoint
    /// is keyed by `mfaChallengeToken`, so a mistyped address can only be fixed by
    /// re-running login — this is the affordance that tells the user so.
    var onChangeEmail: (() -> Void)?

    var body: some View {
        MFACodeEntryView(
            title: L10n.MFA.title,
            subtitle: L10n.MFA.subtitle,
            email: viewModel.email,
            code: $viewModel.verificationCode,
            isLoading: viewModel.isLoading,
            verifyButtonTitle: L10n.MFA.verify,
            window: viewModel.codeWindow,
            onVerify: { Task { await viewModel.verifyMFACode() } },
            onResend: { Task { await viewModel.resendMFACode() } },
            footer: { changeEmailLink }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.isLoginSuccessful) { newValue in
            if newValue {
                onVerificationSuccess?()
            }
        }
        .onChange(of: viewModel.showError) { isShowingError in
            // Clear the entered code on error so the user isn't stuck deleting a stale/invalid code by hand.
            if isShowingError {
                viewModel.verificationCode = ""
            }
        }
        .alert(L10n.Login.errorTitle, isPresented: $viewModel.showError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var changeEmailLink: some View {
        Button {
            onChangeEmail?()
        } label: {
            HStack(spacing: 4) {
                Text(L10n.MFA.wrongEmail)
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.onSurfaceVariant)

                Text(L10n.MFA.changeEmail)
                    .font(FMTypography.captionMedium)
                    .foregroundColor(FMColors.primary)
            }
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Preview
#Preview {
    let viewModel = LoginViewModel()
    viewModel.email = "jingowork@gmail.com"
    return NavigationStack {
        MFAVerificationView(viewModel: viewModel)
    }
}
