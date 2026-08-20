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

    // Google State
    /// Separate from `isLoading` so the Google button spins on its own instead of
    /// putting the email/password button into a loading state it didn't trigger.
    @Published var isGoogleLoading = false
    /// Set when `/auth/google/resolve` answers `SIGN_UP_REQUIRED`. The view opens
    /// the onboarding flow prefilled with this account.
    @Published var googleSignUpAccount: GoogleAccount?

    // MFA State
    @Published var showMFAVerification = false
    @Published var mfaChallengeToken = ""
    @Published var resendCodeTimeInSeconds = 60
    @Published var verificationCode = ""

    private let loginUseCase: LoginUseCaseProtocol
    private let signInWithGoogleUseCase: SignInWithGoogleUseCaseProtocol
    /// Google SDK wrapper, owned by the app target. `nil` disables the Google
    /// button — e.g. in previews and tests.
    private let googleAuth: GoogleAuthProviding?
    /// Called after tokens are saved. Receives the Firebase custom token.
    /// Throw to abort login (e.g. Firebase sign-in failed).
    private let firebaseSignIn: ((String) async throws -> Void)?

    public init(
        loginUseCase: LoginUseCaseProtocol? = nil,
        signInWithGoogleUseCase: SignInWithGoogleUseCaseProtocol? = nil,
        googleAuth: GoogleAuthProviding? = nil,
        firebaseSignIn: ((String) async throws -> Void)? = nil
    ) {
        self.loginUseCase = loginUseCase ?? LoginUseCase(authService: AuthService())
        self.signInWithGoogleUseCase = signInWithGoogleUseCase
            ?? SignInWithGoogleUseCase(authService: AuthService())
        self.googleAuth = googleAuth
        self.firebaseSignIn = firebaseSignIn
    }

    /// Whether the Google entry point should be offered at all.
    var isGoogleAvailable: Bool { googleAuth != nil }
    
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
            handleError(error, suggestGoogle: true)
        }
    }

    /// Single entry point for both Google outcomes: an existing account signs in
    /// straight through (no MFA — the Google identity already proves who this is),
    /// and an unknown one hands the account to the onboarding flow.
    func continueWithGoogle() async {
        guard let googleAuth else { return }

        isGoogleLoading = true
        showError = false

        do {
            let account = try await googleAuth.signIn()
            let outcome = try await signInWithGoogleUseCase.execute(idToken: account.idToken)

            switch outcome {
            case .authenticated:
                try await performFirebaseSignIn()
                isGoogleLoading = false
                isLoginSuccessful = true
            case .signUpRequired:
                isGoogleLoading = false
                googleSignUpAccount = account
            }
        } catch {
            isGoogleLoading = false
            // Dismissing Google's sheet is a decision, not a failure — an alert
            // here would scold the user for changing their mind.
            guard (error as? GoogleAuthError) != .cancelled, !error.isCancellation else { return }
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

    /// - Parameter suggestGoogle: point at the Google button when the failure looks
    ///   like rejected credentials. Accounts created through Google are stored with
    ///   `password = null`, so they can never pass email/password sign-in — and
    ///   "forgot password" stays silent for them too. Without this nudge, a user who
    ///   forgot they used Google has no way out of the login screen.
    private func handleError(_ error: Error, suggestGoogle: Bool = false) {
        if let apiError = error as? APIError {
            errorTitle = apiError.errorTitle
        } else {
            errorTitle = L10n.Login.errorTitle
        }
        errorMessage = error.localizedDescription
        if suggestGoogle, isCredentialsRejection(error) {
            errorMessage += "\n\n" + L10n.Login.googleAccountHint
        }
        showError = true
    }

    private func isCredentialsRejection(_ error: Error) -> Bool {
        if let authError = error as? AuthError { return authError == .invalidCredentials }
        guard let status = error.apiStatusCode else { return false }
        return status == 400 || status == 401 || status == 403
    }
}
