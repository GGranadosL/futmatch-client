import Foundation

/// Centralized "Seguridad en pagos" gate — the single entry point both the
/// account-deletion flow and the payment flow call before proceeding, and
/// also what guards turning the toggle itself off.
///
/// No-ops immediately when the preference is OFF. When it's ON, delegates to
/// `ConfirmLocalIdentityUseCase`, which itself no-ops when the device has no
/// usable local credential — so this never hard-blocks a user who can't
/// authenticate locally, only one who actively declines a live prompt.
public protocol AuthorizeSensitiveActionUseCaseProtocol {
    func execute(reason: String) async throws
}

public struct AuthorizeSensitiveActionUseCase: AuthorizeSensitiveActionUseCaseProtocol {
    private let preferenceStore: PaymentSecurityPreferenceStoring
    private let confirmIdentityUseCase: ConfirmLocalIdentityUseCaseProtocol

    init(
        preferenceStore: PaymentSecurityPreferenceStoring,
        confirmIdentityUseCase: ConfirmLocalIdentityUseCaseProtocol
    ) {
        self.preferenceStore = preferenceStore
        self.confirmIdentityUseCase = confirmIdentityUseCase
    }

    public func execute(reason: String) async throws {
        guard preferenceStore.isEnabled else { return }
        try await confirmIdentityUseCase.execute(reason: reason)
    }
}
