import Foundation

/// Local identity check run right before the delete-account confirmation dialog
/// opens. It is a purely on-device gate — nothing is sent to the backend.
public protocol ConfirmDeletionIdentityUseCaseProtocol {
    /// Runs the biometric / passcode prompt. Returns without prompting when the
    /// device has no biometric enrollment and no passcode (so account deletion is
    /// never blocked by a missing local credential). Throws
    /// `BiometricAuthError.failed` when the user fails or cancels the prompt.
    func execute(reason: String) async throws
}

public struct ConfirmDeletionIdentityUseCase: ConfirmDeletionIdentityUseCaseProtocol {
    private let authenticator: BiometricAuthenticating

    public init(authenticator: BiometricAuthenticating) {
        self.authenticator = authenticator
    }

    public func execute(reason: String) async throws {
        guard authenticator.isAvailable() else { return }
        try await authenticator.authenticate(reason: reason)
    }
}
