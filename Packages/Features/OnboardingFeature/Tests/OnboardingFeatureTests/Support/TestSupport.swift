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
        firebaseToken: String? = "fb-1"
    ) -> SignInResponse {
        SignInResponse(data: .init(
            userId: userId,
            deviceId: deviceId,
            authCode: authCode,
            authTokenResponse: withTokens ? .init(accessToken: "access", refreshToken: "refresh") : nil,
            firebaseToken: firebaseToken
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
