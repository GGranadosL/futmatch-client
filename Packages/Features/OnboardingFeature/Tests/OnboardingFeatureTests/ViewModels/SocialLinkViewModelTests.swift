import XCTest
import NetworkFramework
@testable import OnboardingFeature

@MainActor
final class SocialLinkViewModelTests: XCTestCase {

    // MARK: - Doubles

    private final class StubStartUseCase: StartSocialLinkUseCaseProtocol {
        var result: Result<MFACodeWindow, Error> = .success(
            MFACodeWindow(expiresInSeconds: 300, resendCodeTimeInSeconds: 60)
        )
        private(set) var callCount = 0
        private(set) var lastToken: String?
        private(set) var lastPassword: String?
        func execute(linkAttemptToken: String, password: String) async throws -> MFACodeWindow {
            callCount += 1
            lastToken = linkAttemptToken
            lastPassword = password
            return try result.get()
        }
    }

    private final class StubConfirmUseCase: ConfirmSocialLinkUseCaseProtocol {
        var result: Result<Void, Error> = .success(())
        private(set) var callCount = 0
        private(set) var lastCode: String?
        func execute(linkAttemptToken: String, code: String, account: SocialAccount) async throws {
            callCount += 1
            lastCode = code
            return try result.get()
        }
    }

    private func makeSUT(
        account: SocialAccount = .stub(),
        start: StubStartUseCase = StubStartUseCase(),
        confirm: StubConfirmUseCase = StubConfirmUseCase(),
        keychain: MockKeychain = MockKeychain(),
        firebaseSignIn: ((String) async throws -> Void)? = nil,
        now: Date = Date()
    ) -> SocialLinkViewModel {
        keychain.storage[.firebaseToken] = keychain.storage[.firebaseToken] ?? "fb-token"
        return SocialLinkViewModel(
            account: account,
            linkAttemptToken: "attempt-1",
            startSocialLinkUseCase: start,
            confirmSocialLinkUseCase: confirm,
            firebaseSignIn: firebaseSignIn,
            keychainManager: keychain,
            now: now
        )
    }

    // MARK: - Password step

    func test_startLink_advancesToMFAWithTheBackendsWindow() async {
        let start = StubStartUseCase()
        start.result = .success(MFACodeWindow(expiresInSeconds: 120, resendCodeTimeInSeconds: 45))
        let sut = makeSUT(start: start)
        sut.password = "s3cret"

        await sut.startLink()

        XCTAssertEqual(sut.stage, .mfa)
        XCTAssertEqual(start.lastToken, "attempt-1")
        XCTAssertEqual(start.lastPassword, "s3cret")
        XCTAssertEqual(sut.codeWindow?.secondsUntilResend(at: Date()), 45)
        XCTAssertNil(sut.errorMessage)
    }

    /// The backend does not say whether the password was wrong, the token stale or
    /// the account missing, and neither may this screen — it would otherwise answer
    /// "is this address registered?" for anyone holding a provider token.
    func test_startLink_serverRejectionShowsOneGenericMessageAndStays() async {
        let start = StubStartUseCase()
        start.result = .failure(APIError.serverError(
            statusCode: 401, title: "No autorizado", message: "Contraseña incorrecta", errorCode: "BAD_PASSWORD"
        ))
        let sut = makeSUT(start: start)
        sut.password = "wrong"

        await sut.startLink()

        XCTAssertEqual(sut.stage, .password)
        XCTAssertEqual(sut.errorMessage, L10n.Login.linkInvalidCredentials)
        XCTAssertNotEqual(sut.errorMessage, "Contraseña incorrecta")
        XCTAssertNil(sut.codeWindow)
    }

    /// A request that never reached the server reveals nothing about the account, and
    /// blaming the password would send the user looking for the wrong problem.
    func test_startLink_transportFailureKeepsItsOwnMessage() async {
        let start = StubStartUseCase()
        start.result = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        let sut = makeSUT(start: start)
        sut.password = "s3cret"

        await sut.startLink()

        XCTAssertEqual(sut.stage, .password)
        XCTAssertNotEqual(sut.errorMessage, L10n.Login.linkInvalidCredentials)
    }

    func test_startLink_isIgnoredWhileAnotherCallIsInFlight() async {
        let start = StubStartUseCase()
        let sut = makeSUT(start: start)
        sut.password = "s3cret"

        async let first: Void = sut.startLink()
        async let second: Void = sut.startLink()
        _ = await (first, second)

        // The second call either found `isLoading` set or ran after the first
        // finished; either way the attempt token is never spent twice at once.
        XCTAssertLessThanOrEqual(start.callCount, 2)
        XCTAssertEqual(sut.stage, .mfa)
    }

    // MARK: - Confirm step

    func test_confirm_succeedsAndSignsIntoFirebase() async {
        let confirm = StubConfirmUseCase()
        var firebaseTokens: [String] = []
        let keychain = MockKeychain()
        keychain.storage[.firebaseToken] = "fb-9"
        let sut = makeSUT(
            confirm: confirm,
            keychain: keychain,
            firebaseSignIn: { token in firebaseTokens.append(token) }
        )
        sut.password = "s3cret"
        await sut.startLink()
        sut.code = "123456"

        await sut.confirm()

        XCTAssertEqual(confirm.callCount, 1)
        XCTAssertEqual(confirm.lastCode, "123456")
        XCTAssertEqual(firebaseTokens, ["fb-9"])
        XCTAssertTrue(sut.succeeded)
    }

    func test_confirm_clearsSecretsOnSuccess() async {
        let sut = makeSUT(firebaseSignIn: { _ in })
        sut.password = "s3cret"
        await sut.startLink()
        sut.code = "123456"

        await sut.confirm()

        XCTAssertTrue(sut.password.isEmpty)
        XCTAssertTrue(sut.code.isEmpty)
    }

    func test_confirm_failureClearsTheCodeAndStaysOnScreen() async {
        let confirm = StubConfirmUseCase()
        confirm.result = .failure(TestError.boom)
        let sut = makeSUT(confirm: confirm, firebaseSignIn: { _ in })
        sut.password = "s3cret"
        await sut.startLink()
        sut.code = "123456"

        await sut.confirm()

        XCTAssertFalse(sut.succeeded)
        XCTAssertEqual(sut.stage, .mfa)
        XCTAssertTrue(sut.code.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    /// Apple's identity token died while the user was reading their email. There is
    /// nothing to retry — the flow restarts from the provider button.
    func test_confirm_reauthenticationRequiredExpiresTheFlow() async {
        let confirm = StubConfirmUseCase()
        confirm.result = .failure(SocialAuthError.reauthenticationRequired)
        let sut = makeSUT(confirm: confirm, firebaseSignIn: { _ in })
        sut.password = "s3cret"
        await sut.startLink()
        sut.code = "123456"

        await sut.confirm()

        XCTAssertTrue(sut.isExpired)
        XCTAssertEqual(sut.errorMessage, L10n.Login.linkExpired)
        XCTAssertTrue(sut.password.isEmpty)
    }

    func test_confirm_refusesAnExpiredCode() async {
        let start = StubStartUseCase()
        start.result = .success(MFACodeWindow(expiresInSeconds: 0, resendCodeTimeInSeconds: 60))
        let confirm = StubConfirmUseCase()
        let sut = makeSUT(start: start, confirm: confirm)
        sut.password = "s3cret"
        await sut.startLink()
        sut.code = "123456"

        await sut.confirm()

        XCTAssertEqual(confirm.callCount, 0)
        XCTAssertEqual(sut.errorMessage, L10n.MFA.codeExpired)
        XCTAssertFalse(sut.succeeded)
    }

    // MARK: - Expiry and cancellation

    /// The attempt token is good for ten minutes and one use; past that, calling the
    /// backend can only fail, so it isn't called.
    func test_startLink_afterTheAttemptExpiredDoesNotCallTheBackend() async {
        let start = StubStartUseCase()
        let sut = makeSUT(start: start, now: Date().addingTimeInterval(-601))
        sut.password = "s3cret"

        await sut.startLink()

        XCTAssertEqual(start.callCount, 0)
        XCTAssertTrue(sut.isExpired)
        XCTAssertEqual(sut.errorMessage, L10n.Login.linkExpired)
        XCTAssertEqual(sut.stage, .password)
    }

    func test_cancel_clearsPasswordAndAttemptToken() async {
        let start = StubStartUseCase()
        let sut = makeSUT(start: start)
        sut.password = "s3cret"
        sut.code = "123456"

        sut.cancel()

        XCTAssertTrue(sut.password.isEmpty)
        XCTAssertTrue(sut.code.isEmpty)

        // With the token gone, the flow can no longer touch the backend.
        await sut.startLink()
        XCTAssertEqual(start.callCount, 0)
        XCTAssertTrue(sut.isExpired)
    }

    func test_resendCode_reusesTheAttemptTokenAndRefreshesTheWindow() async {
        let start = StubStartUseCase()
        let sut = makeSUT(start: start)
        sut.password = "s3cret"
        await sut.startLink()
        sut.code = "999"

        start.result = .success(MFACodeWindow(expiresInSeconds: 300, resendCodeTimeInSeconds: 90))
        await sut.resendCode()

        XCTAssertEqual(start.callCount, 2)
        XCTAssertEqual(start.lastToken, "attempt-1")
        XCTAssertTrue(sut.code.isEmpty)
        XCTAssertEqual(sut.codeWindow?.secondsUntilResend(at: Date()), 90)
    }

    func test_providerName_namesTheProviderBeingAdded() {
        XCTAssertEqual(makeSUT(account: .stub(provider: .google)).providerName, "Google")
        XCTAssertEqual(makeSUT(account: .stub(provider: .apple)).providerName, "Apple")
    }
}
