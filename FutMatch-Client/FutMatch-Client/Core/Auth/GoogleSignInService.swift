import Foundation
import UIKit
import OSLog
import GoogleSignIn
import OnboardingFeature

/// `GoogleAuthProviding` backed by the Google Sign-In SDK.
///
/// Lives in the app target rather than `OnboardingFeature` because the SDK needs
/// UIKit and a presenting view controller — the same reason the Firebase
/// custom-token sign-in is injected into `LoginView` as a closure.
@MainActor
struct GoogleSignInService: GoogleAuthProviding {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FutMatch",
        category: "GoogleSignIn"
    )

    /// `true` once both client ids are available. `CLIENT_ID` only appears in
    /// `true` once both client ids are available — what keeps the button hidden
    /// until the project is actually configured.
    static var isConfigured: Bool {
        clientID?.isEmpty == false && !Config.googleServerClientID.isEmpty
    }

    /// iOS OAuth client id for this app.
    ///
    /// It comes from an OAuth 2.0 iOS client in the Google Cloud project (APIs &
    /// Services ▸ Credentials), created against this bundle id. Firebase Auth is
    /// not involved: the backend validates the ID token against its own web client
    /// id, and this app's Firebase session runs on a custom token from our server.
    ///
    /// Read from `Config` first. The plist fallback exists only because turning on
    /// the Google provider in the Firebase console creates that same iOS client and
    /// writes it into GoogleService-Info.plist as `CLIENT_ID` — so either route
    /// works, and neither is required if the other is used.
    private static var clientID: String? {
        if !Config.googleIOSClientID.isEmpty { return Config.googleIOSClientID }
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let plist = NSDictionary(contentsOf: url) else { return nil }
        return plist["CLIENT_ID"] as? String
    }

    // MARK: - GoogleAuthProviding

    func signIn() async throws -> GoogleAccount {
        try configureIfNeeded()

        guard let presenter = Self.topViewController() else {
            throw GoogleAuthError.notConfigured
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            return try Self.account(from: result.user)
        } catch {
            throw Self.mapped(error)
        }
    }

    func refreshedIdToken() async throws -> String {
        try configureIfNeeded()

        // The onboarding may have been resumed from a draft in a later app
        // session, so there may be no live user object — restore first.
        let user: GIDGoogleUser
        if let current = GIDSignIn.sharedInstance.currentUser {
            user = current
        } else if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
        } else {
            throw GoogleAuthError.noActiveSession
        }

        let refreshed = try await user.refreshTokensIfNeeded()
        guard let idToken = refreshed.idToken?.tokenString, !idToken.isEmpty else {
            throw GoogleAuthError.missingIdToken
        }
        Self.logTokenAudience(idToken, logger: logger)
        return idToken
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Private

    private func configureIfNeeded() throws {
        guard let clientID = Self.clientID, !clientID.isEmpty else {
            logger.error("Missing iOS OAuth client id — set Config.googleIOSClientID, or provide CLIENT_ID in GoogleService-Info.plist")
            throw GoogleAuthError.notConfigured
        }
        let serverClientID = Config.googleServerClientID
        guard !serverClientID.isEmpty else {
            logger.error("Missing GOOGLE_OAUTH_WEB_CLIENT_ID — set Config.googleServerClientID for this environment")
            throw GoogleAuthError.notConfigured
        }

        // Setting serverClientID is what asks Google to mint the ID token for the
        // backend's audience instead of this app's own client id.
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID
        )
    }

    private static func account(from user: GIDGoogleUser) throws -> GoogleAccount {
        guard let idToken = user.idToken?.tokenString, !idToken.isEmpty else {
            throw GoogleAuthError.missingIdToken
        }
        guard let subject = user.userID, !subject.isEmpty else {
            throw GoogleAuthError.missingIdToken
        }

        let profile = user.profile
        // Some Google accounts carry only a single display name, so fall back to
        // splitting it rather than showing the user an empty surname field.
        let (given, family) = splitName(
            givenName: profile?.givenName,
            familyName: profile?.familyName,
            fullName: profile?.name
        )

        return GoogleAccount(
            idToken: idToken,
            // The claim the backend keys on alongside `sub`. The SDK does not
            // expose it, and Google's issuer is fixed for all its ID tokens.
            issuer: "https://accounts.google.com",
            subject: subject,
            email: profile?.email ?? "",
            givenName: given,
            familyName: family,
            pictureURL: profile?.imageURL(withDimension: 320)?.absoluteString
        )
    }

    private static func splitName(
        givenName: String?,
        familyName: String?,
        fullName: String?
    ) -> (given: String, family: String) {
        let given = givenName?.trimmingCharacters(in: .whitespaces) ?? ""
        let family = familyName?.trimmingCharacters(in: .whitespaces) ?? ""
        guard given.isEmpty || family.isEmpty else { return (given, family) }

        let parts = (fullName ?? "").split(separator: " ", maxSplits: 1).map(String.init)
        return (
            given.isEmpty ? (parts.first ?? "") : given,
            family.isEmpty ? (parts.count > 1 ? parts[1] : "") : family
        )
    }

    private static func mapped(_ error: Error) -> Error {
        if (error as NSError).code == GIDSignInError.canceled.rawValue,
           (error as NSError).domain == kGIDSignInErrorDomain {
            return GoogleAuthError.cancelled
        }
        return error
    }

    /// Logs only the ID token's `aud` claim so a misconfigured audience is
    /// diagnosable. The backend requires `aud` to equal its web client id; on iOS
    /// that depends on `serverClientID` being honoured, which is worth confirming
    /// on the first run against a real project.
    ///
    /// Nothing else from the token is logged — the backend's logging rules forbid
    /// tokens, emails, profile URLs and Google subjects in logs.
    private static func logTokenAudience(_ idToken: String, logger: Logger) {
        #if DEBUG
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else { return }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audience = json["aud"] as? String else { return }
        logger.debug("Google ID token audience: \(audience, privacy: .public)")
        #endif
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let root = scene?.keyWindow?.rootViewController else { return nil }

        var controller = root
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }
}
