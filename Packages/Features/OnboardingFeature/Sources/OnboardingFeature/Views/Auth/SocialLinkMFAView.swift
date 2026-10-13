import SwiftUI
import FMDesignSystem

/// Third step of adding a social provider to an existing account: the code emailed
/// to that account. A screen of its own rather than a dialog — this is a security
/// confirmation, not an incidental prompt.
///
/// No email chip: ownership of the account is still unproven at this point, so the
/// address must not be shown.
struct SocialLinkMFAView: View {
    @ObservedObject var viewModel: SocialLinkViewModel

    var body: some View {
        MFACodeEntryView(
            title: L10n.Login.linkMFATitle,
            subtitle: L10n.Login.linkMFASubtitle,
            email: nil,
            code: $viewModel.code,
            isLoading: viewModel.isLoading,
            verifyButtonTitle: L10n.MFA.verify,
            window: viewModel.codeWindow,
            onVerify: { Task { await viewModel.confirm() } },
            onResend: { Task { await viewModel.resendCode() } }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            L10n.Login.errorTitle,
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
