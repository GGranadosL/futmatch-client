import Foundation
import AuthenticationServices
import OnboardingFeature

/// `SocialAuthProviding` backed by `AuthenticationServices`.
///
/// Lives in the app target for the same reason `GoogleSignInService` does — it
/// needs a presentation anchor, which `OnboardingFeature` can't provide.
@MainActor
struct AppleSignInService: SocialAuthProviding {
    var provider: AuthProvider { .apple }

    /// Gated purely on config, unlike Google's client-id check — Apple's
    /// entitlement is compile-time, so the only thing left to gate is whether the
    /// backend endpoints are deployed yet.
    static var isConfigured: Bool { Config.isAppleSignInEnabled }

    // MARK: - SocialAuthProviding

    /// Drives the authorization sheet end to end, the same shape
    /// `GoogleSignInService.signIn()` has — the login screen now uses
    /// `FMAppleSignInButton`, so nothing hands us Apple's request object any
    /// more and this owns the nonce for the whole round trip.
    func signIn() async throws -> SocialAccount {
        let rawNonce = AppleNonce.generate()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        configure(request, rawNonce: rawNonce)

        let coordinator = AppleAuthorizationCoordinator()
        let authorization = try await coordinator.perform(request)
        return try account(from: authorization, rawNonce: rawNonce)
    }

    /// Apple has no silent refresh: a minted identity token cannot be reissued
    /// without presenting the authorization sheet again, and doing that from
    /// deep inside a register call would surprise the user with an unexplained
    /// second Face ID prompt. Instead, `OnboardingViewModel.scheduleCredentialExpiry`
    /// proactively bounces back to login before the original credential expires,
    /// and a fresh `signIn()` (via the login button) is what supplies the next one.
    /// This always throws so a caller that skips that bounce fails loudly instead
    /// of silently registering with a stale token.
    func refreshedCredential(matching identity: SocialDraftIdentity) async throws -> SocialCredential {
        throw SocialAuthError.reauthenticationRequired
    }

    func signOut() {
        // Apple keeps no client-side session to clear — there is nothing to sign
        // out of locally. (Server-side revocation on account deletion is a
        // separate concern, handled by the backend.)
    }

    // MARK: - Private

    /// Maps a completed authorization into a `SocialAccount`, given the raw nonce
    /// from the request that produced it.
    private func account(from authorization: ASAuthorization, rawNonce: String) throws -> SocialAccount {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw SocialAuthError.missingIdToken
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              !idToken.isEmpty else {
            throw SocialAuthError.missingIdToken
        }
        guard let codeData = credential.authorizationCode,
              let authorizationCode = String(data: codeData, encoding: .utf8),
              !authorizationCode.isEmpty else {
            throw SocialAuthError.missingIdToken
        }

        let payload = JWTPayload.decode(idToken)
        let expiresAt = (payload?["exp"] as? Double).map { Date(timeIntervalSince1970: $0) }

        // Apple hands over `fullName` only on the very first authorization; any
        // repeat comes back nil, so the prefill falls back to empty rather than
        // crashing or showing "nil nil".
        let givenName = credential.fullName?.givenName ?? ""
        let familyName = credential.fullName?.familyName ?? ""

        // `email` on the credential is likewise first-authorization-only. The
        // identity token's own `email` claim survives repeats, so fall back to it
        // before giving up — the backend rejects registration outright if both
        // are empty, with a message telling the user how to force a fresh
        // first-authorization (revoke access in Settings).
        let email = credential.email ?? (payload?["email"] as? String) ?? ""

        return SocialAccount(
            credential: SocialCredential(
                provider: .apple,
                idToken: idToken,
                authorizationCode: authorizationCode,
                nonce: rawNonce,
                expiresAt: expiresAt
            ),
            issuer: AuthProvider.apple.issuer,
            subject: credential.user,
            email: email,
            givenName: givenName,
            familyName: familyName,
            pictureURL: nil
        )
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest, rawNonce: String) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleNonce.sha256Hex(rawNonce)
    }
}

/// Bridges `ASAuthorizationController`'s delegate callbacks to `async/await`, so
/// `AppleSignInService.signIn()` reads like any other provider.
@MainActor
private final class AppleAuthorizationCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    func perform(_ request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: Self.mapped(error))
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        PresentationAnchor.keyWindow() ?? ASPresentationAnchor()
    }

    private static func mapped(_ error: Error) -> Error {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return SocialAuthError.cancelled
        }
        return error
    }
}
