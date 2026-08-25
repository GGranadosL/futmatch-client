import AuthenticationServices

/// The half of Apple's sign-in flow that talks to `ASAuthorizationAppleIDRequest`
/// directly. Split out from `SocialAuthProviding` because `SignInWithAppleButton`
/// (SwiftUI, `AuthenticationServices`) owns presentation itself — it hands the
/// request object to `onRequest` and the result to `onCompletion` rather than
/// letting a wrapper drive `ASAuthorizationController` end to end the way
/// `GoogleSignInService.signIn()` does.
///
/// The nonce has to survive between those two callbacks without living in the
/// View or being reconstructed by the service (which has no state), so
/// `LoginViewModel` holds it — it is already a class with state, so nothing new
/// is introduced there.
@MainActor
public protocol AppleAuthorizationHandling {
    /// Sets `requestedScopes = [.fullName, .email]` and `request.nonce` to the
    /// SHA-256 of a freshly generated raw nonce, returning that raw nonce so the
    /// backend can later verify the token's `nonce` claim against it.
    func prepare(_ request: ASAuthorizationAppleIDRequest) -> String

    /// Maps a completed authorization into a `SocialAccount`, given the raw nonce
    /// from the matching `prepare(_:)` call.
    func account(from authorization: ASAuthorization, rawNonce: String) throws -> SocialAccount
}
