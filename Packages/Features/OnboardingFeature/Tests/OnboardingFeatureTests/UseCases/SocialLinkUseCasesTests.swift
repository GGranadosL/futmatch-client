import XCTest
@testable import OnboardingFeature

// MARK: - SignInWithSocialUseCase: the LINK_REQUIRED branch

final class SignInWithSocialLinkOutcomeTests: XCTestCase {

    func test_execute_returnsLinkRequiredWithTheAttemptToken() async throws {
        let service = MockAuthService()
        service.socialResolveResult = .success(.stubLinkRequired(linkAttemptToken: "attempt-1"))
        let keychain = MockKeychain()
        let sut = SignInWithSocialUseCase(authService: service, keychainManager: keychain)

        let outcome = try await sut.execute(credential: .stub())

        XCTAssertEqual(outcome, .linkRequired(linkAttemptToken: "attempt-1"))
    }

    /// `LINK_REQUIRED` proves nothing about who is holding the phone, so no session
    /// may be written from it.
    func test_execute_linkRequiredSavesNothing() async throws {
        let service = MockAuthService()
        service.socialResolveResult = .success(.stubLinkRequired())
        let keychain = MockKeychain()
        let sut = SignInWithSocialUseCase(authService: service, keychainManager: keychain)

        _ = try await sut.execute(credential: .stub())

        XCTAssertTrue(keychain.storage.isEmpty)
    }

    /// The old code would have reported this as a missing session, because
    /// `LINK_REQUIRED` legitimately carries no tokens.
    func test_execute_linkRequiredWithoutTokenThrowsItsOwnError() async {
        let service = MockAuthService()
        service.socialResolveResult = .success(.stubLinkRequired(linkAttemptToken: nil))
        let sut = SignInWithSocialUseCase(authService: service, keychainManager: MockKeychain())

        do {
            _ = try await sut.execute(credential: .stub())
            XCTFail("Expected missingLinkAttemptToken")
        } catch {
            XCTAssertEqual(error as? AuthError, .missingLinkAttemptToken)
        }
    }
}

// MARK: - StartSocialLinkUseCase

final class StartSocialLinkUseCaseTests: XCTestCase {

    func test_execute_forwardsTokenAndPassword() async throws {
        let service = MockAuthService()
        let sut = StartSocialLinkUseCase(authService: service)

        _ = try await sut.execute(linkAttemptToken: "attempt-1", password: "s3cret")

        XCTAssertEqual(service.startSocialLinkCallCount, 1)
        XCTAssertEqual(service.lastStartSocialLinkToken, "attempt-1")
        XCTAssertEqual(service.lastStartSocialLinkPassword, "s3cret")
    }

    /// The countdowns must come from the response, never from a constant.
    func test_execute_buildsTheWindowFromTheResponse() async throws {
        let service = MockAuthService()
        service.startSocialLinkResult = .success(.stub(expiresInSeconds: 120, resendCodeTimeInSeconds: 45))
        let sut = StartSocialLinkUseCase(authService: service)

        let window = try await sut.execute(linkAttemptToken: "attempt-1", password: "s3cret")

        // Compared against the clock, not a captured instant: the window is anchored
        // to whenever the response landed, which is a few milliseconds from now.
        XCTAssertEqual(window.codeExpiresAt.timeIntervalSinceNow, 120, accuracy: 1)
        XCTAssertEqual(window.resendAvailableAt.timeIntervalSinceNow, 45, accuracy: 1)
    }

    func test_execute_propagatesErrors() async {
        let service = MockAuthService()
        service.startSocialLinkResult = .failure(TestError.boom)
        let sut = StartSocialLinkUseCase(authService: service)

        do {
            _ = try await sut.execute(linkAttemptToken: "attempt-1", password: "s3cret")
            XCTFail("Expected boom")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}

// MARK: - ConfirmSocialLinkUseCase

@MainActor
final class ConfirmSocialLinkUseCaseTests: XCTestCase {

    func test_execute_savesTheSessionItGetsBack() async throws {
        let service = MockAuthService()
        service.confirmSocialLinkResult = .success(.stubAuthenticated(
            accessToken: "acc", refreshToken: "ref", userId: "u-9", deviceId: "d-9", firebaseToken: "fb-9"
        ))
        let keychain = MockKeychain()
        let sut = ConfirmSocialLinkUseCase(
            authService: service,
            socialAuth: MockSocialAuthProvider(),
            keychainManager: keychain
        )

        try await sut.execute(linkAttemptToken: "attempt-1", code: "123456", account: .stub())

        XCTAssertEqual(keychain.storage[.accessToken], "acc")
        XCTAssertEqual(keychain.storage[.refreshToken], "ref")
        XCTAssertEqual(keychain.storage[.userId], "u-9")
        XCTAssertEqual(keychain.storage[.deviceId], "d-9")
        XCTAssertEqual(keychain.storage[.firebaseToken], "fb-9")
    }

    func test_execute_sendsTheTokenAndCode() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        keychain.storage[.deviceId] = "trusted-device"
        let sut = ConfirmSocialLinkUseCase(
            authService: service,
            socialAuth: MockSocialAuthProvider(),
            keychainManager: keychain
        )

        try await sut.execute(linkAttemptToken: "attempt-1", code: "123456", account: .stub())

        let request = try XCTUnwrap(service.lastConfirmSocialLinkRequest)
        XCTAssertEqual(request.linkAttemptToken, "attempt-1")
        XCTAssertEqual(request.code, "123456")
        XCTAssertEqual(request.deviceId, "trusted-device")
    }

    /// Google can mint a token silently, and the backend re-verifies it at confirm
    /// time — several minutes after the original sign-in.
    func test_execute_google_usesARefreshedCredential() async throws {
        let service = MockAuthService()
        let provider = MockSocialAuthProvider(provider: .google)
        provider.refreshedCredentialResult = .success(.stub(provider: .google, idToken: "fresh-token"))
        let sut = ConfirmSocialLinkUseCase(
            authService: service,
            socialAuth: provider,
            keychainManager: MockKeychain()
        )

        try await sut.execute(
            linkAttemptToken: "attempt-1",
            code: "123456",
            account: .stub(provider: .google, idToken: "stale-token")
        )

        XCTAssertEqual(provider.refreshedCredentialCallCount, 1)
        XCTAssertEqual(service.lastConfirmSocialLinkRequest?.idToken, "fresh-token")
    }

    /// A refresh failure is not worth losing the attempt over: the token in hand may
    /// still be good, and the backend decides either way.
    func test_execute_google_fallsBackToTheOriginalWhenRefreshFails() async throws {
        let service = MockAuthService()
        let provider = MockSocialAuthProvider(provider: .google)
        provider.refreshedCredentialResult = .failure(TestError.boom)
        let sut = ConfirmSocialLinkUseCase(
            authService: service,
            socialAuth: provider,
            keychainManager: MockKeychain()
        )

        try await sut.execute(
            linkAttemptToken: "attempt-1",
            code: "123456",
            account: .stub(provider: .google, idToken: "original-token")
        )

        XCTAssertEqual(service.lastConfirmSocialLinkRequest?.idToken, "original-token")
    }

    /// Apple has no silent refresh — asking for one always throws — so the original
    /// credential is sent, with its authorization code, which the backend exchanges
    /// for the refresh token it needs to revoke the credential later.
    func test_execute_apple_reusesTheOriginalCredential() async throws {
        let service = MockAuthService()
        let provider = MockSocialAuthProvider(provider: .apple)
        provider.refreshedCredentialResult = .failure(SocialAuthError.reauthenticationRequired)
        let sut = ConfirmSocialLinkUseCase(
            authService: service,
            socialAuth: provider,
            keychainManager: MockKeychain()
        )
        let account = SocialAccount.stub(
            provider: .apple,
            credential: .stub(
                provider: .apple,
                idToken: "apple-identity-token",
                authorizationCode: "apple-auth-code",
                nonce: "raw-nonce",
                expiresAt: Date().addingTimeInterval(600)
            )
        )

        try await sut.execute(linkAttemptToken: "attempt-1", code: "123456", account: account)

        XCTAssertEqual(provider.refreshedCredentialCallCount, 0)
        let request = try XCTUnwrap(service.lastConfirmSocialLinkRequest)
        XCTAssertEqual(request.idToken, "apple-identity-token")
        XCTAssertEqual(request.authorizationCode, "apple-auth-code")
        XCTAssertEqual(request.nonce, "raw-nonce")
    }

    /// Apple's token lifetime is the real ceiling on this flow. Reporting it here
    /// means the user is told to start over instead of watching the backend reject
    /// a token we already knew was dead.
    func test_execute_apple_expiredCredentialThrowsBeforeCallingTheBackend() async {
        let service = MockAuthService()
        let sut = ConfirmSocialLinkUseCase(
            authService: service,
            socialAuth: MockSocialAuthProvider(provider: .apple),
            keychainManager: MockKeychain()
        )
        let account = SocialAccount.stub(
            provider: .apple,
            credential: .stub(
                provider: .apple,
                idToken: "apple-identity-token",
                expiresAt: Date().addingTimeInterval(-1)
            )
        )

        do {
            try await sut.execute(linkAttemptToken: "attempt-1", code: "123456", account: account)
            XCTFail("Expected reauthenticationRequired")
        } catch {
            XCTAssertEqual(error as? SocialAuthError, .reauthenticationRequired)
            XCTAssertEqual(service.confirmSocialLinkCallCount, 0)
        }
    }

    func test_execute_withoutASessionThrowsAndSavesNothing() async {
        let service = MockAuthService()
        service.confirmSocialLinkResult = .success(.stubSignUpRequired())
        let keychain = MockKeychain()
        let sut = ConfirmSocialLinkUseCase(
            authService: service,
            socialAuth: MockSocialAuthProvider(),
            keychainManager: keychain
        )

        do {
            try await sut.execute(linkAttemptToken: "attempt-1", code: "123456", account: .stub())
            XCTFail("Expected missingSocialSession")
        } catch {
            XCTAssertEqual(error as? AuthError, .missingSocialSession)
            XCTAssertTrue(keychain.storage.isEmpty)
        }
    }

    func test_execute_propagatesErrors() async {
        let service = MockAuthService()
        service.confirmSocialLinkResult = .failure(TestError.boom)
        let sut = ConfirmSocialLinkUseCase(
            authService: service,
            socialAuth: MockSocialAuthProvider(),
            keychainManager: MockKeychain()
        )

        do {
            try await sut.execute(linkAttemptToken: "attempt-1", code: "123456", account: .stub())
            XCTFail("Expected boom")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
