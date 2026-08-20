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
}
