import SwiftUI
import FMDesignSystem

/// The whole "add Google/Apple to the account you already have" flow, mounted over
/// the auth landing screen when `/auth/{provider}/resolve` answers `LINK_REQUIRED`.
///
/// Two steps: an explicit confirmation that also takes the account's password, then
/// the code emailed to that account on its own pushed screen. Both live here so the
/// landing view only has to decide *whether* to show the flow, not how it is staged.
///
/// Owns the ViewModel — and therefore the attempt token, the password and the
/// provider credential — so all of it is released the moment the flow is dismissed.
struct SocialLinkFlowView: View {
    @StateObject private var viewModel: SocialLinkViewModel

    /// Linking finished; the session is in the Keychain and the app can swap to Home.
    let onLinked: () -> Void
    /// The user backed out, or the attempt expired. `message` is non-nil only for
    /// the expiry case, which needs an explanation.
    let onDismiss: (_ message: String?) -> Void

    /// `@autoclosure` so the ViewModel is built exactly once, on first render —
    /// `StateObject` would discard any later instance anyway, and building one per
    /// render would spin up a use-case graph each time.
    init(
        viewModel: @autoclosure @escaping () -> SocialLinkViewModel,
        onLinked: @escaping () -> Void,
        onDismiss: @escaping (_ message: String?) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel())
        self.onLinked = onLinked
        self.onDismiss = onDismiss
    }

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .overlay {
                if viewModel.stage == .password {
                    passwordConfirmation
                }
            }
            .navigationDestination(isPresented: showMFA) {
                SocialLinkMFAView(viewModel: viewModel)
            }
            .onChange(of: viewModel.succeeded) { didSucceed in
                guard didSucceed else { return }
                onLinked()
            }
            .onChange(of: viewModel.isExpired) { isExpired in
                guard isExpired else { return }
                onDismiss(L10n.Login.linkExpired)
            }
    }

    /// Deliberately says nothing about the existing account — no email, no name.
    /// The user has proved nothing yet, so the screen must not confirm that a
    /// particular address is registered.
    private var passwordConfirmation: some View {
        FMTextFieldConfirmationAlert(
            title: L10n.Login.linkTitle,
            message: L10n.Login.linkMessage(viewModel.providerName),
            textFieldLabel: L10n.Login.linkPasswordLabel,
            text: $viewModel.password,
            isSecureTextField: true,
            errorMessage: viewModel.errorMessage,
            primaryButtonTitle: L10n.Common.continue,
            // The default is the destructive red this component uses for the
            // delete-account gate; adding a sign-in method is not destructive.
            primaryButtonColor: FMColors.primary,
            secondaryButtonTitle: L10n.Common.cancel,
            isLoading: viewModel.isLoading,
            isPrimaryEnabled: viewModel.isPasswordValid,
            onPrimaryAction: {
                Task { await viewModel.startLink() }
            },
            onSecondaryAction: {
                viewModel.cancel()
                onDismiss(nil)
            }
        )
    }

    /// Swiping back off the MFA screen abandons the attempt rather than returning to
    /// the password dialog: the emailed code is already spent and the attempt token
    /// is single-use, so there is nothing to go back to.
    private var showMFA: Binding<Bool> {
        Binding(
            get: { viewModel.stage == .mfa && !viewModel.succeeded },
            set: { isPresented in
                guard !isPresented, !viewModel.succeeded else { return }
                viewModel.cancel()
                onDismiss(nil)
            }
        )
    }
}
