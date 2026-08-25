import AuthenticationServices
import Foundation
import NetworkFramework
import PersistenceFramework

/// Login ViewModel
@MainActor
public class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorTitle = ""
    @Published var errorMessage = ""
    @Published var isLoginSuccessful = false

    // Social Auth State
    /// Which provider is currently mid-flow, if any. Separate from `isLoading` so
    /// the social buttons spin on their own instead of putting the email/password
    /// button into a loading state it didn't trigger.
    @Published private(set) var loadingProvider: AuthProvider?
    /// Set when `/auth/{provider}/resolve` answers `SIGN_UP_REQUIRED`. The view
    /// opens the onboarding flow prefilled with this account.
    @Published var socialSignUpAccount: SocialAccount?

    // MFA State
    @Published var showMFAVerification = false
    @Published var mfaChallengeToken = ""
    @Published var resendCodeTimeInSeconds = 60
    @Published var verificationCode = ""

    private let loginUseCase: LoginUseCaseProtocol
    private let signInWithSocialUseCase: SignInWithSocialUseCaseProtocol
    /// Provider SDK wrappers, owned by the app target. A missing entry disables
    /// that provider's button — e.g. in previews and tests, or when Apple isn't
    /// configured yet.
    private let socialProviders: [AuthProvider: any SocialAuthProviding]
    /// Called after tokens are saved. Receives the Firebase custom token.
    /// Throw to abort login (e.g. Firebase sign-in failed).
    private let firebaseSignIn: ((String) async throws -> Void)?

    public init(
        loginUseCase: LoginUseCaseProtocol? = nil,
        signInWithSocialUseCase: SignInWithSocialUseCaseProtocol? = nil,
        socialProviders: [AuthProvider: any SocialAuthProviding] = [:],
        firebaseSignIn: ((String) async throws -> Void)? = nil
    ) {
        self.loginUseCase = loginUseCase ?? LoginUseCase(authService: AuthService())
        self.signInWithSocialUseCase = signInWithSocialUseCase
            ?? SignInWithSocialUseCase(authService: AuthService())
        self.socialProviders = socialProviders
        self.firebaseSignIn = firebaseSignIn
    }

    /// Whether the Google entry point should be offered at all.
    var isGoogleAvailable: Bool { socialProviders[.google] != nil }
    /// Whether the Apple entry point should be offered at all.
    var isAppleAvailable: Bool { socialProviders[.apple] != nil }
    var isGoogleLoading: Bool { loadingProvider == .google }
    var isAppleLoading: Bool { loadingProvider == .apple }

    var isFormValid: Bool {
        FieldValidator.validateEmail(email).isValid &&
        FieldValidator.validatePasswordForLogin(password).isValid
    }

    func login() async {
        isLoading = true
        isLoginSuccessful = false
        showError = false

        // Normalize before sending — a leading space from paste/autocorrect or a
        // capitalized address silently routes the code nowhere. Registration already
        // does this (`OnboardingViewModel.verifyCode`); login didn't. Written back to
        // the published value so the MFA screen shows exactly what was sent.
        email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let result = try await loginUseCase.execute(email: email, password: password)

            if result.requiresMFA {
                isLoading = false
                mfaChallengeToken = result.challengeToken ?? ""
                resendCodeTimeInSeconds = result.resendCodeTimeInSeconds
                showMFAVerification = true
            } else {
                try await performFirebaseSignIn()
                isLoading = false
                isLoginSuccessful = true
            }
        } catch {
            isLoading = false
            handleError(error, suggestSocial: true)
        }
    }

    func continueWithGoogle() async {
        await continueWith(.google)
    }

    /// Drives Google's own account picker end to end. Apple does not use this
    /// path — `SignInWithAppleButton` owns its own presentation, so Apple goes
    /// through `prepareAppleRequest`/`completeAppleSignIn` instead, both landing
    /// on the same `handleSocialAccount(_:)` once an account is in hand.
    private func continueWith(_ provider: AuthProvider) async {
        guard let auth = socialProviders[provider] else { return }

        loadingProvider = provider
        showError = false

        do {
            let account = try await auth.signIn()
            await handleSocialAccount(account)
        } catch {
            loadingProvider = nil
            // Dismissing the provider's sheet is a decision, not a failure — an
            // alert here would scold the user for changing their mind.
            guard (error as? SocialAuthError) != .cancelled, !error.isCancellation else { return }
            handleError(error)
        }
    }

    /// Raw nonce generated for the in-flight Apple authorization, alive only
    /// between `SignInWithAppleButton`'s `onRequest` and `onCompletion`.
    private var pendingAppleNonce: String?

    /// `SignInWithAppleButton`'s `onRequest` callback: sets the requested scopes
    /// and nonce on Apple's own request object.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        guard let appleAuth = socialProviders[.apple] as? any AppleAuthorizationHandling else { return }
        pendingAppleNonce = appleAuth.prepare(request)
        loadingProvider = .apple
        showError = false
    }

    /// `SignInWithAppleButton`'s `onCompletion` callback.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        let nonce = pendingAppleNonce
        pendingAppleNonce = nil

        guard let appleAuth = socialProviders[.apple] as? any AppleAuthorizationHandling, let nonce else {
            loadingProvider = nil
            return
        }

        do {
            let authorization = try result.get()
            let account = try appleAuth.account(from: authorization, rawNonce: nonce)
            await handleSocialAccount(account)
        } catch {
            loadingProvider = nil
            // Same contract as Google: cancelling the sheet is silent, not an error.
            guard (error as? ASAuthorizationError)?.code != .canceled, !error.isCancellation else { return }
            handleError(error)
        }
    }

    /// Single entry point for both outcomes of any provider, once an account has
    /// been obtained: an existing account signs in straight through (no MFA — the
    /// social identity already proves who this is), and an unknown one hands the
    /// account to the onboarding flow.
    ///
    /// Not `private`: `ASAuthorizationAppleIDCredential`/`ASAuthorization` have no
    /// public initializer, so `completeAppleSignIn`'s success path can't be driven
    /// end to end from a test. This is the seam tests use instead to cover the
    /// same outcome branching Apple and Google both funnel through.
    func handleSocialAccount(_ account: SocialAccount) async {
        do {
            let outcome = try await signInWithSocialUseCase.execute(credential: account.credential)

            switch outcome {
            case .authenticated:
                try await performFirebaseSignIn()
                loadingProvider = nil
                isLoginSuccessful = true
            case .signUpRequired:
                loadingProvider = nil
                socialSignUpAccount = account
            }
        } catch {
            loadingProvider = nil
            guard (error as? SocialAuthError) != .cancelled, !error.isCancellation else { return }
            handleError(error)
        }
    }

    func verifyMFACode() async {
        isLoading = true
        showError = false

        do {
            _ = try await loginUseCase.verifyMFACode(
                challengeToken: mfaChallengeToken,
                code: verificationCode
            )
            try await performFirebaseSignIn()
            isLoading = false
            showMFAVerification = false
            isLoginSuccessful = true
        } catch {
            isLoading = false
            handleError(error)
        }
    }

    func resendMFACode() async {
        isLoading = true
        showError = false

        do {
            let result = try await loginUseCase.sendMFACode(
                challengeToken: mfaChallengeToken
            )
            isLoading = false
            resendCodeTimeInSeconds = result.resendCodeTimeInSeconds
        } catch {
            isLoading = false
            handleError(error)
        }
    }

    /// Abandons the in-flight MFA challenge and returns to the login form so the user
    /// can fix a mistyped address. The challenge token is tied to the email that was
    /// submitted, so it can't be reused — the next attempt has to go through `login()`
    /// again.
    func cancelMFAToCorrectEmail() {
        showMFAVerification = false
        mfaChallengeToken = ""
        verificationCode = ""
        showError = false
    }

    // MARK: - Private Helpers

    /// Reads the Firebase token saved by the use case and calls the injected sign-in closure.
    /// Throws `AuthError.firebaseSignInFailed` if the token is missing or sign-in fails.
    private func performFirebaseSignIn() async throws {
        guard let signIn = firebaseSignIn else { return }
        guard let token = KeychainManager.shared.firebaseToken, !token.isEmpty else {
            throw AuthError.firebaseSignInFailed
        }
        try await signIn(token)
    }

    /// - Parameter suggestSocial: point at the Google/Apple buttons when the failure
    ///   looks like rejected credentials. Accounts created through a social provider
    ///   are stored with `password = null`, so they can never pass email/password
    ///   sign-in — and "forgot password" stays silent for them too. Without this
    ///   nudge, a user who forgot which provider they used has no way out of the
    ///   login screen.
    private func handleError(_ error: Error, suggestSocial: Bool = false) {
        if let apiError = error as? APIError {
            errorTitle = apiError.errorTitle
        } else {
            errorTitle = L10n.Login.errorTitle
        }
        errorMessage = error.localizedDescription
        if suggestSocial, isCredentialsRejection(error) {
            errorMessage += "\n\n" + L10n.Login.socialAccountHint
        }
        showError = true
    }

    private func isCredentialsRejection(_ error: Error) -> Bool {
        if let authError = error as? AuthError { return authError == .invalidCredentials }
        guard let status = error.apiStatusCode else { return false }
        return status == 400 || status == 401 || status == 403
    }
}
