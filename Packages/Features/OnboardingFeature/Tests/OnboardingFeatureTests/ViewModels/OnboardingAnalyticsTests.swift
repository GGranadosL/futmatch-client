import XCTest
import SharedModels
@testable import OnboardingFeature

@MainActor
final class OnboardingAnalyticsTests: XCTestCase {

    private struct Boom: Error {}

    // MARK: - Login

    private func makeLogin(_ auth: MockAuthService, _ spy: SpyAnalytics) -> LoginViewModel {
        let sut = LoginViewModel(
            loginUseCase: LoginUseCase(authService: auth, keychainManager: MockKeychain()),
            analytics: spy
        )
        sut.email = "user@example.com"
        sut.password = "pw"
        return sut
    }

    func test_login_success_emitsStartedThenSuccess() async {
        let spy = SpyAnalytics()
        await makeLogin(MockAuthService(), spy).login()

        XCTAssertEqual(spy.names, ["login_started", "login_success"])
        XCTAssertEqual(spy.events.last?.parameters, ["method": .string("email")])
    }

    func test_login_mfaRequired_doesNotEmitSuccessYet() async {
        let auth = MockAuthService()
        auth.signInResult = .success(.stub(authCode: "SUCCESS_NEED_MFA", withTokens: false, challengeToken: "ch"))
        let spy = SpyAnalytics()
        await makeLogin(auth, spy).login()

        XCTAssertEqual(spy.names, ["login_started", "login_mfa_required"])
    }

    func test_login_failure_emitsStableCode_withoutMessage() async {
        let auth = MockAuthService()
        auth.signInResult = .failure(AuthError.invalidCredentials)
        let spy = SpyAnalytics()
        await makeLogin(auth, spy).login()

        XCTAssertEqual(spy.names, ["login_started", "login_error"])
        XCTAssertEqual(spy.events.last?.parameters["error_code"], .string("INVALID_CREDENTIALS"))
    }

    func test_verifyMFA_failure_emitsMfaErrorWithVerifyStage_andNoLoginSuccess() async {
        let auth = MockAuthService()
        auth.signInResult = .success(.stub(authCode: "SUCCESS_NEED_MFA", withTokens: false, challengeToken: "ch"))
        auth.mfaVerifyResult = .failure(Boom())
        let spy = SpyAnalytics()
        let sut = makeLogin(auth, spy)
        await sut.login()
        sut.verificationCode = "123456"
        await sut.verifyMFACode()

        XCTAssertEqual(spy.names.last, "login_mfa_error")
        XCTAssertEqual(spy.events.last?.parameters["stage"], .string("verify_code"))
        XCTAssertFalse(spy.names.contains("login_success"))
    }

    // MARK: - Password reset

    private func makeReset(_ auth: MockAuthService, _ spy: SpyAnalytics) -> ForgotPasswordCoordinatorViewModel {
        ForgotPasswordCoordinatorViewModel(
            forgotPasswordUseCase: ForgotPasswordUseCase(authService: auth),
            verifyResetMFAUseCase: VerifyResetMFAUseCase(authService: auth),
            resetPasswordUseCase: ResetPasswordUseCase(authService: auth),
            analytics: spy
        )
    }

    func test_passwordReset_happyPath_emitsEachStepOnce() async {
        let spy = SpyAnalytics()
        let sut = makeReset(MockAuthService(), spy)

        await sut.sendForgotPasswordEmail("user@example.com")
        await sut.verifyCode("123456", email: "user@example.com")
        if case let .newPassword(token) = sut.currentState {
            await sut.resetPassword("NewPass123!", resetToken: token)
        }

        XCTAssertEqual(spy.names, [
            "password_reset_started", "password_reset_code_sent", "password_reset_code_verified",
            "password_reset_submitted", "password_reset_success"
        ])
    }

    func test_passwordReset_secondRequestFromVerificationScreen_isAResend() async {
        let spy = SpyAnalytics()
        let sut = makeReset(MockAuthService(), spy)

        await sut.sendForgotPasswordEmail("user@example.com")
        await sut.sendForgotPasswordEmail("user@example.com")

        XCTAssertEqual(spy.names, ["password_reset_started", "password_reset_code_sent", "password_reset_code_resent"])
    }

    func test_passwordReset_sendFailure_emitsErrorWithSendCodeStage() async {
        let auth = MockAuthService()
        auth.forgotPasswordResult = .failure(Boom())
        let spy = SpyAnalytics()
        await makeReset(auth, spy).sendForgotPasswordEmail("user@example.com")

        XCTAssertEqual(spy.events.last?.name, "password_reset_error")
        XCTAssertEqual(spy.events.last?.parameters["stage"], .string("send_code"))
        XCTAssertEqual(spy.events.last?.parameters["error_code"], .string("UNKNOWN"))
    }
}

@MainActor
final class SocialLoginAnalyticsTests: XCTestCase {
    func test_appleSignIn_reportsAppleMethod() async {
        let provider = MockSocialAuthProvider()
        provider.signInResult = .success(.stub(credential: .stub(provider: .apple)))
        let auth = MockAuthService()
        auth.socialResolveResult = .success(.stubAuthenticated())
        let spy = SpyAnalytics()
        let sut = LoginViewModel(
            signInWithSocialUseCase: SignInWithSocialUseCase(authService: auth, keychainManager: MockKeychain()),
            socialProviders: [.apple: provider],
            analytics: spy
        )

        await sut.continueWithApple()

        XCTAssertEqual(spy.names, ["login_started", "login_success"])
        XCTAssertEqual(spy.events[0].parameters["method"], .string("apple"))
        XCTAssertEqual(spy.events[1].parameters["method"], .string("apple"))
    }
}
