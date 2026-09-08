import Foundation
import LocalAuthentication

// MARK: - Errors

public enum BiometricAuthError: Error {
    /// A live prompt was shown and the user failed or cancelled it (or the
    /// system/app interrupted it). Callers must block the protected action.
    case failed
    /// No usable local credential exists, or the app isn't permitted to use
    /// biometrics — discovered only once `evaluatePolicy` actually ran
    /// (`isAvailable()` already filters the common case ahead of time).
    /// Callers must let the action through.
    case notPermitted
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
    /// Throws `BiometricAuthError.notPermitted` when the credential turns out
    /// to be unusable (not enrolled, no passcode, or the app isn't permitted
    /// to use biometrics), and `BiometricAuthError.failed` when the user
    /// actively failed or cancelled the live prompt.
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
        } catch let laError as LAError {
            throw Self.mappedError(for: laError)
        } catch {
            throw BiometricAuthError.failed
        }
    }

    /// `.biometryNotAvailable` covers both "hardware unavailable" and, per
    /// Apple's docs, "not permitted for this app" — the exact case that must
    /// fail open rather than block. `.biometryNotEnrolled`/`.passcodeNotSet`
    /// are defensive parity with `isAvailable()` for a TOCTOU race between the
    /// check and the prompt. Everything else represents an active attempt
    /// (cancel, fallback, lockout, failure) and must block.
    private static func mappedError(for laError: LAError) -> BiometricAuthError {
        switch laError.code {
        case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
            return .notPermitted
        default:
            return .failed
        }
    }
}
