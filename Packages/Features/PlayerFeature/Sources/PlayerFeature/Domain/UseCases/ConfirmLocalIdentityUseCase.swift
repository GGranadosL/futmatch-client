import Foundation

/// Local identity check run before a sensitive on-device action (account
/// deletion, payment, disabling payment security). A purely on-device gate —
/// nothing is sent to the backend.
public protocol ConfirmLocalIdentityUseCaseProtocol {
    /// Runs the biometric / passcode prompt. Returns without prompting when
    /// the device has no biometric enrollment and no passcode, and also when
    /// the OS reports the credential is unusable / not permitted for this app
    /// (`BiometricAuthError.notPermitted`) — so the caller is never blocked by
    /// a missing or inaccessible local credential. Throws
    /// `BiometricAuthError.failed` only when the user actively failed or
    /// cancelled the live prompt.
    func execute(reason: String) async throws
}

public struct ConfirmLocalIdentityUseCase: ConfirmLocalIdentityUseCaseProtocol {
    private let authenticator: BiometricAuthenticating

    public init(authenticator: BiometricAuthenticating) {
        self.authenticator = authenticator
    }

    public func execute(reason: String) async throws {
        guard authenticator.isAvailable() else { return }
        do {
            try await authenticator.authenticate(reason: reason)
        } catch BiometricAuthError.notPermitted {
            return
        }
    }
}
