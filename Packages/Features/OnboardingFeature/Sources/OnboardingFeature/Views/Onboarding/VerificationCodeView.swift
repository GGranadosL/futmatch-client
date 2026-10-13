import SwiftUI
import FMDesignSystem

/// Registration email verification — a thin wrapper over `MFACodeEntryView`.
///
/// What's specific here is the inline error banner (this screen reports a wrong
/// code in place rather than through an alert) and the shake that goes with it.
struct VerificationCodeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var code: String = ""
    @State private var shakeOffset: CGFloat = 0

    let email: String

    init(viewModel: OnboardingViewModel, email: String) {
        self.viewModel = viewModel
        self.email = email
    }

    var body: some View {
        MFACodeEntryView(
            iconSystemName: "envelope.badge",
            title: L10n.Verification.title,
            subtitle: L10n.Verification.subtitle,
            email: email,
            code: $code,
            isLoading: viewModel.isLoading,
            verifyButtonTitle: L10n.Verification.confirm,
            window: viewModel.codeWindow,
            onVerify: { verifyCode(code) },
            onResend: { resendCode() },
            footer: { footerContent }
        )
        .offset(x: shakeOffset)
        .navigationTitle(L10n.Verification.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: code) { newValue in
            // Only dismiss error when the user starts typing (not when we clear programmatically)
            if viewModel.errorMessage != nil, !newValue.isEmpty {
                viewModel.errorMessage = nil
            }
        }
    }

    // MARK: - Subviews

    /// Keeps the original three-line header — subtitle, address, instruction — with
    /// the inline error slotted in below it.
    private var footerContent: some View {
        VStack(spacing: 12) {
            Text(L10n.Verification.instruction)
                .font(FMTypography.caption)
                .foregroundColor(FMColors.onSurfaceVariant)
                .multilineTextAlignment(.center)

            errorBanner
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(FMColors.error)
                Text(error)
                    .font(FMTypography.caption)
                    .foregroundColor(FMColors.error)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMColors.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
        }
    }

    // MARK: - Actions

    private func verifyCode(_ codeToVerify: String) {
        Task {
            await viewModel.verifyCode(codeToVerify)
            if viewModel.errorMessage != nil {
                // Clear fields and shake so user can re-enter immediately
                code = ""
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) {
                    shakeOffset = -12
                }
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 10).delay(0.1)) {
                    shakeOffset = 0
                }
            }
        }
    }

    private func resendCode() {
        Task {
            await viewModel.resendVerificationCode()
            code = ""
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        VerificationCodeView(
            viewModel: OnboardingViewModel(),
            email: "diego.beltran@mexample.com"
        )
    }
}
