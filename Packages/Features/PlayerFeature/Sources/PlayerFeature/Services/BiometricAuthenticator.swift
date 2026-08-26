import Foundation
import LocalAuthentication

// MARK: - Errors

/// The device could evaluate owner authentication but the user failed or
/// cancelled it. A missing enrollment is *not* an error — see `BiometricAuthenticating`.
public enum BiometricAuthError: Error {
    case failed
}

// MARK: - Protocol

/// Thin abstraction over `LocalAuthentication` so the delete-account flow can gate
/// on Face ID / Touch ID (with device-passcode fallback) without depending on
/// `LAContext` directly.
public protocol BiometricAuthenticating {
    /// `true` when the device can evaluate `deviceOwnerAuthentication`
    /// (a biometric is enrolled or a passcode is set).
    func isAvailable() -> Bool

    /// Prompts for Face ID / Touch ID, falling back to the device passcode.
    /// Throws `BiometricAuthError.failed` if the user fails or cancels.
    func authenticate(reason: String) async throws
}

// MARK: - Implementation

struct BiometricAuthenticator: BiometricAuthenticating {
    func isAvailable() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        do {
            _ = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            throw BiometricAuthError.failed
        }
    }
}
