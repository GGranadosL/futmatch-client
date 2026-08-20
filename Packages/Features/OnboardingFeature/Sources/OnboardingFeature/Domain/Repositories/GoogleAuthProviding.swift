import Foundation

/// Abstraction over the Google Sign-In SDK.
///
/// The concrete implementation lives in the app target (it needs UIKit and a
/// presenting view controller), and is injected in — the same arrangement the
/// Firebase custom-token sign-in already uses via `LoginView(firebaseSignIn:)`.
/// Keeping the SDK out of this package leaves the feature testable with a mock.
///
/// Main-actor isolated because Google's SDK must be driven from the main thread —
/// it presents a view controller. The async requirements stay callable from any
/// context; only `signOut()` has to be reached from the main actor.
@MainActor
public protocol GoogleAuthProviding {
    /// Presents Google's account picker and returns the chosen identity.
    /// Throws `GoogleAuthError.cancelled` when the user dismisses the sheet.
    func signIn() async throws -> GoogleAccount

    /// Returns a freshly minted ID token for the account that is already signed
    /// in, restoring the previous session if needed.
    ///
    /// The backend requires a valid, unexpired token at register time, and the
    /// token is never persisted locally — so an onboarding that was resumed from
    /// a draft has to mint a new one here rather than reuse the one from `signIn`.
    func refreshedIdToken() async throws -> String

    /// Clears the local Google session so the next sign-in shows the account picker.
    func signOut()
}

// MARK: - Errors

public enum GoogleAuthError: LocalizedError, Equatable {
    /// The user dismissed Google's sheet. Callers should stay silent — this is
    /// not a failure worth an alert.
    case cancelled
    /// The SDK returned no ID token, or the app is misconfigured (missing
    /// `CLIENT_ID` in GoogleService-Info.plist / missing server client ID).
    case missingIdToken
    case notConfigured
    /// No signed-in Google session to refresh — the user has to pick an account again.
    case noActiveSession

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return L10n.Login.googleCancelled
        case .missingIdToken, .notConfigured, .noActiveSession:
            return L10n.Login.googleGenericError
        }
    }
}
