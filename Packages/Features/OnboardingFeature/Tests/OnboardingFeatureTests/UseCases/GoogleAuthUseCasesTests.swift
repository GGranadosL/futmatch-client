import XCTest
@testable import OnboardingFeature

// MARK: - SignInWithGoogleUseCase

final class SignInWithGoogleUseCaseTests: XCTestCase {

    func test_execute_signUpRequired_doesNotSaveTokens() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        service.googleResolveResult = .success(.stubSignUpRequired())
        let sut = SignInWithGoogleUseCase(authService: service, keychainManager: keychain)

        let outcome = try await sut.execute(idToken: "id-token")

        XCTAssertEqual(outcome, .signUpRequired)
        XCTAssertNil(keychain.storage[.accessToken])
    }

    func test_execute_authenticated_savesTokens() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        service.googleResolveResult = .success(.stubAuthenticated())
        let sut = SignInWithGoogleUseCase(authService: service, keychainManager: keychain)

        let outcome = try await sut.execute(idToken: "id-token")

        XCTAssertEqual(outcome, .authenticated)
        XCTAssertEqual(keychain.storage[.accessToken], "google-access-token")
        XCTAssertEqual(keychain.storage[.refreshToken], "google-refresh-token")
        XCTAssertEqual(keychain.storage[.firebaseToken], "google-firebase-token")
    }

    /// A trusted device skips a fresh challenge, so the stored id has to go out.
    func test_execute_forwardsStoredDeviceId() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        try keychain.save("device-42", for: .deviceId)
        let sut = SignInWithGoogleUseCase(authService: service, keychainManager: keychain)

        _ = try await sut.execute(idToken: "id-token")

        XCTAssertEqual(service.lastGoogleResolveDeviceId, "device-42")
    }

    /// Success without tokens is a broken contract, not a silent no-op login.
    func test_execute_successWithoutSession_throws() async {
        let service = MockAuthService()
        service.googleResolveResult = .success(GoogleAuthResponse(data: .init(
            flow: "AUTHENTICATED",
            authCode: nil,
            authResponse: nil,
            userId: nil,
            deviceId: nil,
            authTokenResponse: nil,
            firebaseToken: nil
        )))
        let sut = SignInWithGoogleUseCase(authService: service, keychainManager: MockKeychain())

        do {
            _ = try await sut.execute(idToken: "id-token")
            XCTFail("Expected missingGoogleSession")
        } catch {
            XCTAssertEqual(error as? AuthError, .missingGoogleSession)
        }
    }
}

// MARK: - RegisterGoogleUserUseCase

@MainActor
final class RegisterGoogleUserUseCaseTests: XCTestCase {

    private func makeInput(
        profilePictureSource: ProfilePictureSource = .google
    ) -> GoogleRegistrationInput {
        GoogleRegistrationInput(
            name: "Diego",
            lastName: "Lopez",
            phone: "+525512345678",
            country: "MX",
            birthDate: 946_684_800_000,
            gender: .male,
            playerPosition: .midfielder,
            level: .intermediate,
            profilePictureSource: profilePictureSource
        )
    }

    /// The stored ID token is never reused — the backend requires a fresh one.
    func test_execute_mintsFreshTokenAndMapsRequest() async throws {
        let service = MockAuthService()
        let google = MockGoogleAuthProvider()
        google.refreshedIdTokenResult = .success("fresh-token")
        let sut = RegisterGoogleUserUseCase(
            authService: service,
            googleAuth: google,
            keychainManager: MockKeychain()
        )

        try await sut.execute(makeInput())

        XCTAssertEqual(google.refreshedIdTokenCallCount, 1)
        let request = try XCTUnwrap(service.lastGoogleRegisterRequest)
        XCTAssertEqual(request.idToken, "fresh-token")
        XCTAssertEqual(request.name, "Diego")
        XCTAssertEqual(request.lastName, "Lopez")
        XCTAssertEqual(request.phone, "+525512345678")
        XCTAssertEqual(request.country, "MX")
        XCTAssertEqual(request.birthDate, 946_684_800_000)
        XCTAssertEqual(request.gender, .male)
        XCTAssertEqual(request.playerPosition, .midfielder)
        XCTAssertEqual(request.level, .intermediate)
        XCTAssertEqual(request.profilePictureSource, .google)
    }

    func test_execute_savesReturnedSession() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        let sut = RegisterGoogleUserUseCase(
            authService: service,
            googleAuth: MockGoogleAuthProvider(),
            keychainManager: keychain
        )

        try await sut.execute(makeInput())

        XCTAssertEqual(keychain.storage[.accessToken], "google-access-token")
    }

    /// A retry that finds the existing identity resolves instead of duplicating,
    /// and reports it with a different authCode. Presence of tokens is the test.
    func test_execute_acceptsResolvedRetryAuthCode() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        service.googleRegisterResult = .success(.stubAuthenticated(flow: nil, authCode: "SUCCESS"))
        let sut = RegisterGoogleUserUseCase(
            authService: service,
            googleAuth: MockGoogleAuthProvider(),
            keychainManager: keychain
        )

        try await sut.execute(makeInput())

        XCTAssertEqual(keychain.storage[.accessToken], "google-access-token")
    }

    func test_execute_customPicture_isReported() async throws {
        let service = MockAuthService()
        let sut = RegisterGoogleUserUseCase(
            authService: service,
            googleAuth: MockGoogleAuthProvider(),
            keychainManager: MockKeychain()
        )

        try await sut.execute(makeInput(profilePictureSource: .custom))

        XCTAssertEqual(service.lastGoogleRegisterRequest?.profilePictureSource, .custom)
    }
}

// MARK: - Draft identity matching

final class GoogleDraftMatchingTests: XCTestCase {

    private func makeSUT(_ draft: OnboardingDraft) -> GetOnboardingDraftUseCase {
        let repo = MockOnboardingRepository()
        repo.getDraftResult = .success((draft: draft, password: nil))
        return GetOnboardingDraftUseCase(repository: repo)
    }

    private func googleDraft(subject: String = "google-subject-1") -> OnboardingDraft {
        OnboardingDraft(
            firstName: "Diego",
            googleIssuer: "https://accounts.google.com",
            googleSubject: subject
        )
    }

    func test_googleFlow_restoresMatchingDraft() async throws {
        let sut = makeSUT(googleDraft())

        let result = try await sut.execute(googleIdentity: GoogleAccount.stub().draftIdentity)

        XCTAssertEqual(result?.draft.firstName, "Diego")
    }

    /// A different Google account must never inherit someone else's half-filled form.
    func test_googleFlow_ignoresDraftFromAnotherAccount() async throws {
        let sut = makeSUT(googleDraft(subject: "someone-else"))

        let result = try await sut.execute(googleIdentity: GoogleAccount.stub().draftIdentity)

        XCTAssertNil(result)
    }

    /// Restoring a Google draft into the password flow builds a registration with
    /// no password, which the backend rejects.
    func test_passwordFlow_ignoresGoogleDraft() async throws {
        let sut = makeSUT(googleDraft())

        let result = try await sut.execute(googleIdentity: nil)

        XCTAssertNil(result)
    }

    func test_googleFlow_ignoresPasswordDraft() async throws {
        let sut = makeSUT(OnboardingDraft(firstName: "Ana"))

        let result = try await sut.execute(googleIdentity: GoogleAccount.stub().draftIdentity)

        XCTAssertNil(result)
    }

    func test_passwordFlow_restoresPasswordDraft() async throws {
        let sut = makeSUT(OnboardingDraft(firstName: "Ana"))

        let result = try await sut.execute(googleIdentity: nil)

        XCTAssertEqual(result?.draft.firstName, "Ana")
    }
}

// MARK: - Response decoding

/// Pins the real wire format. The first build shipped `authCode` as a required
/// field, so the sign-up-required payload — which carries nothing but `flow` —
/// failed to decode and surfaced as "no se han podido leer los datos".
final class GoogleAuthResponseDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> GoogleAuthResponse {
        try JSONDecoder().decode(GoogleAuthResponse.self, from: Data(json.utf8))
    }

    func test_decodesSignUpRequired_withOnlyFlow() throws {
        let response = try decode(#"{"data":{"flow":"SIGN_UP_REQUIRED"}}"#)

        XCTAssertTrue(response.requiresSignUp)
        XCTAssertNil(response.session)
    }

    /// The actual shape `/auth/google/resolve` returns for `AUTHENTICATED`: the
    /// session nested under `authResponse`, not flat under `data`. The first build
    /// assumed flat and decoded this to an empty session, which surfaced as "no se
    /// pudo completar el inicio de sesión con Google" despite a 200 response.
    func test_decodesRealAuthenticatedPayload() throws {
        let response = try decode(#"""
        {"data":{"flow":"AUTHENTICATED","authResponse":{
          "deviceId":"d-1","firebaseToken":"fb","userId":"u-1",
          "authTokenResponse":{"accessToken":"at","refreshToken":"rt"},
          "authCode":"SUCCESS"
        }}}
        """#)

        XCTAssertFalse(response.requiresSignUp)
        let session = try XCTUnwrap(response.session)
        XCTAssertEqual(session.accessToken, "at")
        XCTAssertEqual(session.refreshToken, "rt")
        XCTAssertEqual(session.userId, "u-1")
        XCTAssertEqual(session.deviceId, "d-1")
        XCTAssertEqual(session.firebaseToken, "fb")
    }

    /// Older flat shape (`data.userId`, `data.authTokenResponse`, …) — no longer
    /// seen from `/auth/google/resolve`, but `session` still falls back to it in
    /// case `/auth/google/register` (unverified) or a future revision uses it.
    func test_decodesFlatSessionAsFallback() throws {
        let response = try decode(#"""
        {"data":{"flow":"AUTHENTICATED","userId":"u-1","deviceId":"d-1",
        "firebaseToken":"fb","authTokenResponse":{"accessToken":"at","refreshToken":"rt"}}}
        """#)

        XCTAssertFalse(response.requiresSignUp)
        let session = try XCTUnwrap(response.session)
        XCTAssertEqual(session.accessToken, "at")
        XCTAssertEqual(session.refreshToken, "rt")
        XCTAssertEqual(session.userId, "u-1")
        XCTAssertEqual(session.deviceId, "d-1")
        XCTAssertEqual(session.firebaseToken, "fb")
    }

    /// The register endpoint reuses the standard auth envelope, which names the
    /// discriminator `authCode`.
    func test_decodesAuthCodeDiscriminator() throws {
        let response = try decode(#"{"data":{"authCode":"SIGN_UP_REQUIRED"}}"#)

        XCTAssertTrue(response.requiresSignUp)
    }

    /// Unknown extra fields must not break decoding.
    func test_toleratesUnknownFields() throws {
        let response = try decode(#"{"data":{"flow":"SIGN_UP_REQUIRED","somethingNew":42}}"#)

        XCTAssertTrue(response.requiresSignUp)
    }
}
