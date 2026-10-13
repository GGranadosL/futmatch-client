import Foundation
import NetworkFramework

@MainActor
final class DeleteAccountViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var succeeded = false

    /// True while the pre-dialog biometric / passcode prompt is on screen.
    @Published private(set) var isVerifyingIdentity = false
    /// Flips to `true` once identity is confirmed — the view opens the
    /// confirmation dialog in response, then calls `resetIdentityConfirmation()`.
    @Published private(set) var identityConfirmed = false
    /// Set when the biometric / passcode prompt fails or is cancelled; the view
    /// surfaces it as an error toast. The confirmation dialog is not shown.
    @Published private(set) var biometricErrorMessage: String?

    private let deleteAccountUseCase: DeleteAccountUseCaseProtocol
    private let authorizeUseCase: AuthorizeSensitiveActionUseCaseProtocol

    init(
        deleteAccountUseCase: DeleteAccountUseCaseProtocol,
        authorizeUseCase: AuthorizeSensitiveActionUseCaseProtocol
    ) {
        self.deleteAccountUseCase = deleteAccountUseCase
        self.authorizeUseCase = authorizeUseCase
    }

    /// Step 1 — triggered by the "Delete account" button. Runs the local identity
    /// gate; on success `identityConfirmed` flips so the view can present the
    /// confirmation dialog.
    func requestDeletion() async {
        isVerifyingIdentity = true
        biometricErrorMessage = nil
        errorMessage = nil
        do {
            try await authorizeUseCase.execute(reason: L10n.DeleteAccount.biometricReason)
            identityConfirmed = true
        } catch {
            biometricErrorMessage = L10n.DeleteAccount.biometricFailedError
        }
        isVerifyingIdentity = false
    }

    func resetIdentityConfirmation() {
        identityConfirmed = false
    }

    func clearBiometricError() {
        biometricErrorMessage = nil
    }

    /// `true` when `text` matches the localized confirmation phrase, ignoring case
    /// and surrounding whitespace. Used both to enable the primary button and to
    /// guard `deleteAccount(confirmation:)`.
    func isConfirmationValid(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(L10n.DeleteAccount.confirmationPhrase, options: .caseInsensitive) == .orderedSame
    }

    /// Step 2 — triggered by the dialog's primary button.
    func deleteAccount(confirmation typed: String) async {
        guard isConfirmationValid(typed) else {
            errorMessage = L10n.DeleteAccount.phraseMismatchError
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await deleteAccountUseCase.execute()
            succeeded = true
        } catch {
            errorMessage = error.apiErrorMessage ?? L10n.DeleteAccount.genericError
        }
        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }
}
