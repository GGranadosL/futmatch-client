import Foundation

/// Abstraction over a social sign-in SDK (Google, Apple, ...).
///
/// The concrete implementation lives in the app target (it needs UIKit and a
/// presenting view controller / anchor), and is injected in — the same arrangement
/// the Firebase custom-token sign-in already uses via `LoginView(firebaseSignIn:)`.
/// Keeping the SDKs out of this package leaves the feature testable with a mock.
///
/// Main-actor isolated because both SDKs must be driven from the main thread — they
/// present a view controller / authorization sheet. The async requirements stay
/// callable from any context; only `signOut()` has to be reached from the main actor.
@MainActor
public protocol SocialAuthProviding {
    var provider: AuthProvider { get }

    /// Presents the provider's account picker and returns the chosen identity.
    /// Throws `SocialAuthError.cancelled` when the user dismisses the sheet.
    func signIn() async throws -> SocialAccount

    /// Returns a fresh credential for the account matching `identity`, for an
    /// onboarding that may have been resumed hours later.
    ///
    /// Google can mint this silently by restoring the previous sign-in and
    /// refreshing the token. Apple cannot — there is no silent refresh, so its
    /// implementation always throws `SocialAuthError.reauthenticationRequired`;
    /// callers must treat that as "bounce back to login and let the user tap the
    /// button again", not as a retryable error.
    func refreshedCredential(matching identity: SocialDraftIdentity) async throws -> SocialCredential

    /// Clears the local session so the next sign-in shows the account picker again.
    /// A no-op for providers (like Apple) that keep no client-side session.
    func signOut()
}

// MARK: - Errors

public enum SocialAuthError: LocalizedError, Equatable {
    /// The user dismissed the provider's sheet. Callers should stay silent — this
    /// is not a failure worth an alert.
    case cancelled
    /// The SDK returned no token, or the app is misconfigured.
    case missingIdToken
    case notConfigured
    /// No signed-in session to refresh — the user has to pick an account again.
    case noActiveSession
    /// `refreshedCredential(matching:)` resolved to a different account than the
    /// one the draft belongs to.
    case identityMismatch
    /// This provider cannot refresh a credential without user interaction.
    case reauthenticationRequired

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return L10n.Login.socialCancelled
        case .missingIdToken, .notConfigured, .noActiveSession, .identityMismatch, .reauthenticationRequired:
            return L10n.Login.socialGenericError
        }
    }
}
