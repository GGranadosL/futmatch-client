import XCTest
@testable import OnboardingFeature

// MARK: - SignInWithSocialUseCase

final class SignInWithSocialUseCaseTests: XCTestCase {

    func test_execute_signUpRequired_doesNotSaveTokens() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        service.socialResolveResult = .success(.stubSignUpRequired())
        let sut = SignInWithSocialUseCase(authService: service, keychainManager: keychain)

        let outcome = try await sut.execute(credential: .stub())

        XCTAssertEqual(outcome, .signUpRequired)
        XCTAssertNil(keychain.storage[.accessToken])
    }

    func test_execute_authenticated_savesTokens() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        service.socialResolveResult = .success(.stubAuthenticated())
        let sut = SignInWithSocialUseCase(authService: service, keychainManager: keychain)

        let outcome = try await sut.execute(credential: .stub())

        XCTAssertEqual(outcome, .authenticated)
        XCTAssertEqual(keychain.storage[.accessToken], "social-access-token")
        XCTAssertEqual(keychain.storage[.refreshToken], "social-refresh-token")
        XCTAssertEqual(keychain.storage[.firebaseToken], "social-firebase-token")
    }

    /// A trusted device skips a fresh challenge, so the stored id has to go out.
    func test_execute_forwardsStoredDeviceId() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        try keychain.save("device-42", for: .deviceId)
        let sut = SignInWithSocialUseCase(authService: service, keychainManager: keychain)

        _ = try await sut.execute(credential: .stub())

        XCTAssertEqual(service.lastSocialResolveDeviceId, "device-42")
    }

    /// Apple's credential carries a nonce; it must reach the request untouched.
    func test_execute_apple_forwardsProviderAndNonce() async throws {
        let service = MockAuthService()
        let sut = SignInWithSocialUseCase(authService: service, keychainManager: MockKeychain())

        _ = try await sut.execute(credential: .stub(provider: .apple, idToken: "apple-token", nonce: "raw-nonce"))

        XCTAssertEqual(service.lastSocialResolveProvider, .apple)
        XCTAssertEqual(service.lastSocialResolveIdToken, "apple-token")
        XCTAssertEqual(service.lastSocialResolveNonce, "raw-nonce")
    }

    /// Success without tokens is a broken contract, not a silent no-op login.
    func test_execute_successWithoutSession_throws() async {
        let service = MockAuthService()
        service.socialResolveResult = .success(SocialAuthResponse(data: .init(
            flow: "AUTHENTICATED",
            authCode: nil,
            authResponse: nil,
            userId: nil,
            deviceId: nil,
            authTokenResponse: nil,
            firebaseToken: nil
        )))
        let sut = SignInWithSocialUseCase(authService: service, keychainManager: MockKeychain())

        do {
            _ = try await sut.execute(credential: .stub())
            XCTFail("Expected missingSocialSession")
        } catch {
            XCTAssertEqual(error as? AuthError, .missingSocialSession)
        }
    }
}

// MARK: - RegisterSocialUserUseCase

@MainActor
final class RegisterSocialUserUseCaseTests: XCTestCase {

    private func makeInput(
        provider: AuthProvider = .google,
        credential: SocialCredential? = nil,
        profilePictureSource: ProfilePictureSource? = .providerImported
    ) -> SocialRegistrationInput {
        SocialRegistrationInput(
            identity: SocialDraftIdentity(provider: provider, issuer: provider.issuer, subject: "subject-1"),
            credential: credential ?? .stub(provider: provider, idToken: "signup-time-token"),
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

    /// For Google, the stored credential is never reused — the backend requires a
    /// fresh one, obtained by calling `refreshedCredential(matching:)` rather than
    /// reusing whatever was captured at sign-in time.
    func test_execute_google_mintsFreshCredentialAndMapsRequest() async throws {
        let service = MockAuthService()
        let social = MockSocialAuthProvider()
        social.refreshedCredentialResult = .success(.stub(idToken: "fresh-token"))
        let sut = RegisterSocialUserUseCase(
            authService: service,
            socialAuth: social,
            keychainManager: MockKeychain()
        )

        try await sut.execute(makeInput())

        XCTAssertEqual(social.refreshedCredentialCallCount, 1)
        let request = try XCTUnwrap(service.lastSocialRegisterRequest)
        XCTAssertEqual(request.idToken, "fresh-token")
        XCTAssertEqual(request.name, "Diego")
        XCTAssertEqual(request.lastName, "Lopez")
        XCTAssertEqual(request.phone, "+525512345678")
        XCTAssertEqual(request.country, "MX")
        XCTAssertEqual(request.birthDate, 946_684_800_000)
        XCTAssertEqual(request.gender, .male)
        XCTAssertEqual(request.playerPosition, .midfielder)
        XCTAssertEqual(request.level, .intermediate)
        XCTAssertEqual(request.profilePictureSource, .providerImported)
    }

    func test_execute_savesReturnedSession() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        let sut = RegisterSocialUserUseCase(
            authService: service,
            socialAuth: MockSocialAuthProvider(),
            keychainManager: keychain
        )

        try await sut.execute(makeInput())

        XCTAssertEqual(keychain.storage[.accessToken], "social-access-token")
    }

    /// A retry that finds the existing identity resolves instead of duplicating,
    /// and reports it with a different authCode. Presence of tokens is the test.
    func test_execute_acceptsResolvedRetryAuthCode() async throws {
        let service = MockAuthService()
        let keychain = MockKeychain()
        service.socialRegisterResult = .success(.stubAuthenticated(flow: nil, authCode: "SUCCESS"))
        let sut = RegisterSocialUserUseCase(
            authService: service,
            socialAuth: MockSocialAuthProvider(),
            keychainManager: keychain
        )

        try await sut.execute(makeInput())

        XCTAssertEqual(keychain.storage[.accessToken], "social-access-token")
    }

    func test_execute_customPicture_isReported() async throws {
        let service = MockAuthService()
        let sut = RegisterSocialUserUseCase(
            authService: service,
            socialAuth: MockSocialAuthProvider(),
            keychainManager: MockKeychain()
        )

        try await sut.execute(makeInput(profilePictureSource: .custom))

        XCTAssertEqual(service.lastSocialRegisterRequest?.profilePictureSource, .custom)
    }

    /// Apple's request carries the ORIGINAL credential from sign-up time, with its
    /// authorization code and nonce, and no picture source field at all — Apple
    /// never supplies an avatar. Crucially, `refreshedCredential` is never called:
    /// Apple can't mint a new one without presenting the sheet again, so calling
    /// it here would just throw `reauthenticationRequired` and lose the sign-up.
    func test_execute_apple_usesOriginalCredential_neverCallsRefresh() async throws {
        let service = MockAuthService()
        let social = MockSocialAuthProvider(provider: .apple)
        social.refreshedCredentialResult = .failure(SocialAuthError.reauthenticationRequired)
        let sut = RegisterSocialUserUseCase(
            authService: service,
            socialAuth: social,
            keychainManager: MockKeychain()
        )
        let credential = SocialCredential.stub(
            provider: .apple,
            idToken: "apple-signup-token",
            authorizationCode: "auth-code-1",
            nonce: "raw-nonce-1"
        )

        try await sut.execute(makeInput(provider: .apple, credential: credential, profilePictureSource: nil))

        XCTAssertEqual(social.refreshedCredentialCallCount, 0)
        let request = try XCTUnwrap(service.lastSocialRegisterRequest)
        XCTAssertEqual(request.provider, .apple)
        XCTAssertEqual(request.idToken, "apple-signup-token")
        XCTAssertEqual(request.authorizationCode, "auth-code-1")
        XCTAssertEqual(request.nonce, "raw-nonce-1")
        XCTAssertNil(request.profilePictureSource)
    }

    /// A mismatched identity must propagate and must not save any tokens — the
    /// caller asked to register account A and the provider handed back account B.
    /// (Google path — Apple never calls `refreshedCredential` at all, see above.)
    func test_execute_identityMismatch_propagatesAndSavesNothing() async {
        let service = MockAuthService()
        let social = MockSocialAuthProvider()
        social.refreshedCredentialResult = .failure(SocialAuthError.identityMismatch)
        let keychain = MockKeychain()
        let sut = RegisterSocialUserUseCase(
            authService: service,
            socialAuth: social,
            keychainManager: keychain
        )

        do {
            try await sut.execute(makeInput())
            XCTFail("Expected identityMismatch")
        } catch {
            XCTAssertEqual(error as? SocialAuthError, .identityMismatch)
        }
        XCTAssertNil(keychain.storage[.accessToken])
        XCTAssertEqual(service.socialRegisterCallCount, 0)
    }
}

// MARK: - Draft identity matching

final class SocialDraftMatchingTests: XCTestCase {

    private func makeSUT(_ draft: OnboardingDraft) -> GetOnboardingDraftUseCase {
        let repo = MockOnboardingRepository()
        repo.getDraftResult = .success((draft: draft, password: nil))
        return GetOnboardingDraftUseCase(repository: repo)
    }

    private func socialDraft(provider: AuthProvider = .google, subject: String = "subject-1") -> OnboardingDraft {
        OnboardingDraft(
            firstName: "Diego",
            provider: provider,
            socialIssuer: provider.issuer,
            socialSubject: subject
        )
    }

    func test_googleFlow_restoresMatchingDraft() async throws {
        let sut = makeSUT(socialDraft(provider: .google, subject: "google-subject-1"))

        let result = try await sut.execute(socialIdentity: SocialAccount.stub(subject: "google-subject-1").draftIdentity)

        XCTAssertEqual(result?.draft.firstName, "Diego")
    }

    /// A different Google account must never inherit someone else's half-filled form.
    func test_googleFlow_ignoresDraftFromAnotherAccount() async throws {
        let sut = makeSUT(socialDraft(provider: .google, subject: "someone-else"))

        let result = try await sut.execute(socialIdentity: SocialAccount.stub(subject: "google-subject-1").draftIdentity)

        XCTAssertNil(result)
    }

    /// Restoring a social draft into the password flow builds a registration with
    /// no password, which the backend rejects.
    func test_passwordFlow_ignoresSocialDraft() async throws {
        let sut = makeSUT(socialDraft())

        let result = try await sut.execute(socialIdentity: nil)

        XCTAssertNil(result)
    }

    func test_googleFlow_ignoresPasswordDraft() async throws {
        let sut = makeSUT(OnboardingDraft(firstName: "Ana"))

        let result = try await sut.execute(socialIdentity: SocialAccount.stub().draftIdentity)

        XCTAssertNil(result)
    }

    func test_passwordFlow_restoresPasswordDraft() async throws {
        let sut = makeSUT(OnboardingDraft(firstName: "Ana"))

        let result = try await sut.execute(socialIdentity: nil)

        XCTAssertEqual(result?.draft.firstName, "Ana")
    }

    /// The N-way matrix Apple adds on top of Google's original 5 cases.
    func test_appleFlow_restoresMatchingDraft() async throws {
        let sut = makeSUT(socialDraft(provider: .apple, subject: "apple-subject-1"))

        let result = try await sut.execute(socialIdentity: SocialAccount.stub(provider: .apple, subject: "apple-subject-1").draftIdentity)

        XCTAssertEqual(result?.draft.firstName, "Diego")
    }

    /// A Google draft must never be handed to an Apple sign-up, even with a
    /// matching subject string — the provider itself is part of the identity.
    func test_appleFlow_ignoresGoogleDraft() async throws {
        let sut = makeSUT(socialDraft(provider: .google, subject: "same-subject"))

        let result = try await sut.execute(socialIdentity: SocialAccount.stub(provider: .apple, subject: "same-subject").draftIdentity)

        XCTAssertNil(result)
    }

    /// And the reverse: an Apple draft must never leak into a Google sign-up.
    func test_googleFlow_ignoresAppleDraft() async throws {
        let sut = makeSUT(socialDraft(provider: .apple, subject: "same-subject"))

        let result = try await sut.execute(socialIdentity: SocialAccount.stub(provider: .google, subject: "same-subject").draftIdentity)

        XCTAssertNil(result)
    }

    /// A row written by the pre-Apple build has `socialIssuer`/`socialSubject` set
    /// (renamed at the CoreData level from `googleIssuer`/`googleSubject`) but no
    /// `socialProvider`. The repository backfills `.google` from the issuer before
    /// this use case ever sees it, so the matcher itself doesn't need to know about
    /// legacy rows — this test pins that the backfilled draft still matches.
    func test_legacyDraftWithoutProvider_backfilledAsGoogle_stillMatches() async throws {
        let legacyDraft = OnboardingDraft(
            firstName: "Legacy",
            provider: .google,
            socialIssuer: AuthProvider.google.issuer,
            socialSubject: "legacy-subject"
        )
        let sut = makeSUT(legacyDraft)

        let result = try await sut.execute(socialIdentity: SocialAccount.stub(subject: "legacy-subject").draftIdentity)

        XCTAssertEqual(result?.draft.firstName, "Legacy")
    }
}

// MARK: - Response decoding

/// Pins the real wire format. The first build shipped `authCode` as a required
/// field, so the sign-up-required payload — which carries nothing but `flow` —
/// failed to decode and surfaced as "no se han podido leer los datos". Shared by
/// every `/auth/{provider}/*` endpoint, so this stays provider-agnostic.
final class SocialAuthResponseDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> SocialAuthResponse {
        try JSONDecoder().decode(SocialAuthResponse.self, from: Data(json.utf8))
    }

    func test_decodesSignUpRequired_withOnlyFlow() throws {
        let response = try decode(#"{"data":{"flow":"SIGN_UP_REQUIRED"}}"#)

        XCTAssertTrue(response.requiresSignUp)
        XCTAssertNil(response.session)
    }

    /// The actual shape `/auth/{provider}/resolve` returns for `AUTHENTICATED`: the
    /// session nested under `authResponse`, not flat under `data`. The first build
    /// assumed flat and decoded this to an empty session, which surfaced as "no se
    /// pudo completar el inicio de sesión" despite a 200 response.
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

    /// Older flat shape (`data.userId`, `data.authTokenResponse`, …) — kept as a
    /// fallback in case a future backend revision uses it.
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

// MARK: - Apple account mapping

/// Covers the two ways Apple diverges from Google at the mapping layer: the name
/// may be empty (no crash, no "nil nil"), and the email fallback to the JWT
/// payload when the credential itself carries none.
@MainActor
final class AppleAccountMappingTests: XCTestCase {

    func test_sanitizedName_emptyInput_staysEmpty() {
        XCTAssertEqual(OnboardingViewModel.sanitizedName(""), "")
    }

    func test_socialAccount_appleProvider_hasNoPictureURL() {
        let account = SocialAccount.stub(provider: .apple, subject: "apple-subject-1", pictureURL: nil)

        XCTAssertNil(account.pictureURL)
        XCTAssertEqual(account.issuer, AuthProvider.apple.issuer)
    }
}
