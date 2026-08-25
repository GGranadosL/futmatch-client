import XCTest
import PersistenceFramework
@testable import OnboardingFeature

@MainActor
final class LoginViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(auth: MockAuthService) -> LoginViewModel {
        LoginViewModel(
            loginUseCase: LoginUseCase(authService: auth, keychainManager: MockKeychain())
        )
    }

    // MARK: - Email normalization

    /// A pasted or autocorrected address arrives with a leading space or capitals and
    /// the verification code silently goes nowhere. Registration already normalized;
    /// login didn't.
    func test_login_trimsAndLowercasesEmail_beforeSending() async {
        let auth = MockAuthService()
        let sut = makeSUT(auth: auth)
        sut.email = "  Jingo.Work@Gmail.COM "
        sut.password = "pw"

        await sut.login()

        XCTAssertEqual(auth.lastSignInEmail, "jingo.work@gmail.com")
    }

    /// The MFA screen renders `viewModel.email`, so the normalized value has to be
    /// written back — otherwise the user is shown a different address than the one
    /// the code was actually sent to.
    func test_login_writesNormalizedEmailBack_soMFAScreenShowsWhatWasSent() async {
        let auth = MockAuthService()
        let sut = makeSUT(auth: auth)
        sut.email = " USER@Example.com "
        sut.password = "pw"

        await sut.login()

        XCTAssertEqual(sut.email, "user@example.com")
        XCTAssertEqual(sut.email, auth.lastSignInEmail)
    }

    func test_login_leavesAlreadyNormalizedEmailUntouched() async {
        let auth = MockAuthService()
        let sut = makeSUT(auth: auth)
        sut.email = "user@example.com"
        sut.password = "pw"

        await sut.login()

        XCTAssertEqual(auth.lastSignInEmail, "user@example.com")
    }

    // MARK: - Correcting a mistyped address

    func test_cancelMFAToCorrectEmail_dropsChallenge_butKeepsEmailToEdit() async {
        let auth = MockAuthService()
        auth.signInResult = .success(.stub(authCode: "SUCCESS_NEED_MFA", withTokens: false, challengeToken: "ch-1"))
        let sut = makeSUT(auth: auth)
        sut.email = "user@gmial.com"
        sut.password = "pw"
        await sut.login()
        sut.verificationCode = "123"
        XCTAssertTrue(sut.showMFAVerification)

        sut.cancelMFAToCorrectEmail()

        XCTAssertFalse(sut.showMFAVerification)
        XCTAssertEqual(sut.mfaChallengeToken, "", "The token is keyed to the old address — it can't be reused")
        XCTAssertEqual(sut.verificationCode, "")
        XCTAssertEqual(sut.email, "user@gmial.com", "The typo must survive the pop so the user can fix it in place")
    }

    func test_login_afterCorrectingEmail_issuesAFreshChallenge() async {
        let auth = MockAuthService()
        auth.signInResult = .success(.stub(authCode: "SUCCESS_NEED_MFA", withTokens: false, challengeToken: "ch-1"))
        let sut = makeSUT(auth: auth)
        sut.email = "user@gmial.com"
        sut.password = "pw"
        await sut.login()
        sut.cancelMFAToCorrectEmail()

        auth.signInResult = .success(.stub(authCode: "SUCCESS_NEED_MFA", withTokens: false, challengeToken: "ch-2"))
        sut.email = "user@gmail.com"
        await sut.login()

        XCTAssertEqual(auth.lastSignInEmail, "user@gmail.com")
        XCTAssertEqual(sut.mfaChallengeToken, "ch-2")
        XCTAssertTrue(sut.showMFAVerification)
    }

    // MARK: - Social auth
    //
    // `ASAuthorizationAppleIDCredential`/`ASAuthorization` have no public
    // initializer, so a real Apple success can't be driven from a real Apple SDK
    // object here. These exercise the same outcome branching through
    // `handleSocialAccount(_:)` instead — the seam every provider funnels into
    // once an account is in hand — with a stub tagged `.apple` to prove the
    // branching is provider-agnostic.

    /// An unknown Apple identity hands the account to onboarding — same outcome
    /// Google's `SIGN_UP_REQUIRED` produces, just tagged with the right provider.
    func test_handleSocialAccount_apple_signUpRequired_setsSocialSignUpAccount() async {
        let auth = MockAuthService()
        auth.socialResolveResult = .success(.stubSignUpRequired())
        let sut = LoginViewModel(
            loginUseCase: LoginUseCase(authService: auth, keychainManager: MockKeychain()),
            signInWithSocialUseCase: SignInWithSocialUseCase(authService: auth, keychainManager: MockKeychain())
        )

        await sut.handleSocialAccount(.stub(provider: .apple, subject: "apple-subject-1"))

        XCTAssertEqual(sut.socialSignUpAccount?.provider, .apple)
        XCTAssertFalse(sut.isAppleLoading)
    }

    /// Dismissing Apple's sheet is a decision, not a failure: the provider maps
    /// `ASAuthorizationError.canceled` to `SocialAuthError.cancelled`, and the
    /// view model has to swallow it rather than raise an alert.
    func test_continueWithApple_cancelled_setsNoErrorAndClearsLoading() async {
        let auth = MockAuthService()
        let apple = MockSocialAuthProvider(provider: .apple)
        apple.signInResult = .failure(SocialAuthError.cancelled)
        let sut = LoginViewModel(
            loginUseCase: LoginUseCase(authService: auth, keychainManager: MockKeychain()),
            socialProviders: [.apple: apple]
        )

        await sut.continueWithApple()

        XCTAssertEqual(apple.signInCallCount, 1)
        XCTAssertFalse(sut.showError)
        XCTAssertFalse(sut.isAppleLoading)
    }

    /// A credentials rejection on the password path should point at both social
    /// buttons, not just Google — the hint has to stay accurate now that Apple
    /// exists too.
    func test_login_credentialsRejected_appendsSocialHint() async {
        let auth = MockAuthService()
        auth.signInResult = .failure(AuthError.invalidCredentials)
        let sut = makeSUT(auth: auth)
        sut.email = "user@example.com"
        sut.password = "wrong"

        await sut.login()

        XCTAssertTrue(sut.showError)
        XCTAssertTrue(sut.errorMessage.contains(L10n.Login.socialAccountHint))
    }
}
