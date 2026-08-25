import Foundation
@testable import OnboardingFeature

// MARK: - Shared test error

enum TestError: Error, Equatable {
    case boom
}

// MARK: - Auth response stubs
//
// These response types are `public` structs whose memberwise inits are `internal`,
// so they are reachable here through `@testable import`.

extension SignInResponse {
    static func stub(
        userId: String = "u-1",
        deviceId: String = "d-1",
        authCode: String = "SUCCESS",
        withTokens: Bool = true,
        firebaseToken: String? = "fb-1",
        challengeToken: String? = nil
    ) -> SignInResponse {
        SignInResponse(data: .init(
            userId: userId,
            deviceId: deviceId,
            authCode: authCode,
            authTokenResponse: withTokens ? .init(accessToken: "access", refreshToken: "refresh") : nil,
            firebaseToken: firebaseToken,
            challengeToken: challengeToken
        ))
    }
}

extension MFASendResponse {
    static func stub(
        newCodeSent: Bool = true,
        expiresInSeconds: Int = 300,
        resendCodeTimeInSeconds: Int = 30
    ) -> MFASendResponse {
        MFASendResponse(data: .init(
            newCodeSent: newCodeSent,
            expiresInSeconds: expiresInSeconds,
            resendCodeTimeInSeconds: resendCodeTimeInSeconds
        ))
    }
}

extension MFAVerifyResponse {
    static func stub(
        userId: String = "u-1",
        deviceId: String = "d-1",
        authCode: String = "SUCCESS"
    ) -> MFAVerifyResponse {
        MFAVerifyResponse(data: .init(
            userId: userId,
            deviceId: deviceId,
            authCode: authCode,
            authTokenResponse: .init(accessToken: "access", refreshToken: "refresh"),
            firebaseToken: "fb-1"
        ))
    }
}

extension RegisterCompleteResponse {
    static func stub(
        userId: String = "u-1",
        deviceId: String = "d-1",
        authCode: String = "SUCCESS"
    ) -> RegisterCompleteResponse {
        RegisterCompleteResponse(data: .init(
            userId: userId,
            deviceId: deviceId,
            authCode: authCode,
            authTokenResponse: .init(accessToken: "access", refreshToken: "refresh"),
            firebaseToken: "fb-1"
        ))
    }
}

extension RegisterStartResponse {
    static func stub(
        success: Bool = true,
        message: String = "OK",
        resendCodeTimeInSeconds: Int = 30
    ) -> RegisterStartResponse {
        RegisterStartResponse(data: .init(
            success: success,
            message: message,
            resendCodeTimeInSeconds: resendCodeTimeInSeconds
        ))
    }
}

extension ForgotPasswordResponse {
    static func stub(
        userId: String? = "u-1",
        newCodeSent: Bool = true,
        expiresInSeconds: Int = 300,
        resendCodeTimeInSeconds: Int = 30
    ) -> ForgotPasswordResponse {
        ForgotPasswordResponse(data: .init(
            userId: userId,
            newCodeSent: newCodeSent,
            expiresInSeconds: expiresInSeconds,
            resendCodeTimeInSeconds: resendCodeTimeInSeconds
        ))
    }
}

extension VerifyResetMFAResponse {
    static func stub(resetToken: String = "reset-token") -> VerifyResetMFAResponse {
        VerifyResetMFAResponse(data: .init(resetToken: resetToken))
    }
}

extension ResetPasswordResponse {
    static func stub(success: Bool = true, message: String = "OK") -> ResetPasswordResponse {
        ResetPasswordResponse(data: .init(success: success, message: message))
    }
}

extension SignOutResponse {
    static func stub(success: Bool = true, message: String = "OK") -> SignOutResponse {
        SignOutResponse(data: .init(success: success, message: message))
    }
}

// MARK: - OnboardingDraft stubs

extension OnboardingDraft {
    /// Draft created "now" — not expired.
    static func freshStub(email: String = "a@b.com") -> OnboardingDraft {
        OnboardingDraft(email: email, createdAt: Date())
    }

    /// Draft created more than 24h ago — expired.
    static func expiredStub(email: String = "a@b.com") -> OnboardingDraft {
        OnboardingDraft(email: email, createdAt: Date(timeIntervalSinceNow: -90_000))
    }
}

// MARK: - Social Auth Stubs

extension SocialAuthResponse {
    /// Exactly what `/auth/{provider}/resolve` returns for an unknown identity:
    /// a lone `flow`, no ids and no tokens.
    static func stubSignUpRequired() -> SocialAuthResponse {
        SocialAuthResponse(data: ResponseData(
            flow: "SIGN_UP_REQUIRED",
            authCode: nil,
            authResponse: nil,
            userId: nil,
            deviceId: nil,
            authTokenResponse: nil,
            firebaseToken: nil
        ))
    }

    /// Matches the confirmed real shape: the session nested under `data.authResponse`,
    /// not flat under `data`. See `test_decodesRealAuthenticatedPayload` for the
    /// literal JSON this was pinned against.
    static func stubAuthenticated(
        flow: String? = "AUTHENTICATED",
        authCode: String? = nil,
        accessToken: String = "social-access-token",
        refreshToken: String = "social-refresh-token",
        userId: String = "social-user-id",
        deviceId: String = "social-device-id",
        firebaseToken: String? = "social-firebase-token"
    ) -> SocialAuthResponse {
        SocialAuthResponse(data: ResponseData(
            flow: flow,
            authCode: nil,
            authResponse: NestedSession(
                userId: userId,
                deviceId: deviceId,
                authTokenResponse: AuthTokenResponse(
                    accessToken: accessToken,
                    refreshToken: refreshToken
                ),
                firebaseToken: firebaseToken,
                authCode: authCode
            ),
            userId: nil,
            deviceId: nil,
            authTokenResponse: nil,
            firebaseToken: nil
        ))
    }

    /// The older flat shape (`data.userId`, `data.authTokenResponse`, …) — kept as
    /// a stub so `session`'s fallback path stays covered even though the backend
    /// no longer emits it for `resolve`.
    static func stubAuthenticatedFlat(
        authCode: String = "SUCCESS",
        accessToken: String = "social-access-token",
        refreshToken: String = "social-refresh-token",
        userId: String = "social-user-id",
        deviceId: String = "social-device-id",
        firebaseToken: String? = "social-firebase-token"
    ) -> SocialAuthResponse {
        SocialAuthResponse(data: ResponseData(
            flow: nil,
            authCode: authCode,
            authResponse: nil,
            userId: userId,
            deviceId: deviceId,
            authTokenResponse: AuthTokenResponse(
                accessToken: accessToken,
                refreshToken: refreshToken
            ),
            firebaseToken: firebaseToken
        ))
    }
}

extension SocialCredential {
    static func stub(
        provider: AuthProvider = .google,
        idToken: String = "social-id-token",
        authorizationCode: String? = nil,
        nonce: String? = nil,
        expiresAt: Date? = nil
    ) -> SocialCredential {
        SocialCredential(
            provider: provider,
            idToken: idToken,
            authorizationCode: authorizationCode,
            nonce: nonce,
            expiresAt: expiresAt
        )
    }
}

extension SocialAccount {
    static func stub(
        provider: AuthProvider = .google,
        idToken: String = "google-id-token",
        issuer: String? = nil,
        subject: String = "google-subject-1",
        email: String = "player@gmail.com",
        givenName: String = "Diego",
        familyName: String = "Lopez",
        pictureURL: String? = "https://lh3.googleusercontent.com/a/photo"
    ) -> SocialAccount {
        SocialAccount(
            credential: .stub(provider: provider, idToken: idToken),
            issuer: issuer ?? provider.issuer,
            subject: subject,
            email: email,
            givenName: givenName,
            familyName: familyName,
            pictureURL: pictureURL
        )
    }
}
