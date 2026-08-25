import Foundation
import PersistenceFramework
@testable import OnboardingFeature

// MARK: - MockAuthService

final class MockAuthService: AuthServiceProtocol {

    // registerStart
    var registerStartResult: Result<RegisterStartResponse, Error> = .success(.stub())
    private(set) var lastRegisterStartRequest: RegisterStartRequest?
    func registerStart(_ request: RegisterStartRequest) async throws -> RegisterStartResponse {
        lastRegisterStartRequest = request
        return try registerStartResult.get()
    }

    // registerComplete
    var registerCompleteResult: Result<RegisterCompleteResponse, Error> = .success(.stub())
    private(set) var lastRegisterCompleteEmail: String?
    private(set) var lastRegisterCompleteCode: String?
    func registerComplete(email: String, verificationCode: String) async throws -> RegisterCompleteResponse {
        lastRegisterCompleteEmail = email
        lastRegisterCompleteCode = verificationCode
        return try registerCompleteResult.get()
    }

    // signIn
    var signInResult: Result<SignInResponse, Error> = .success(.stub())
    private(set) var signInCallCount = 0
    private(set) var lastSignInEmail: String?
    private(set) var lastSignInPassword: String?
    private(set) var lastSignInDeviceId: String?
    func signIn(email: String, password: String, deviceId: String?) async throws -> SignInResponse {
        signInCallCount += 1
        lastSignInEmail = email
        lastSignInPassword = password
        lastSignInDeviceId = deviceId
        return try signInResult.get()
    }

    // socialResolve
    var socialResolveResult: Result<SocialAuthResponse, Error> = .success(.stubSignUpRequired())
    private(set) var socialResolveCallCount = 0
    private(set) var lastSocialResolveProvider: AuthProvider?
    private(set) var lastSocialResolveIdToken: String?
    private(set) var lastSocialResolveNonce: String?
    private(set) var lastSocialResolveDeviceId: String?
    func socialResolve(provider: AuthProvider, idToken: String, nonce: String?, deviceId: String?) async throws -> SocialAuthResponse {
        socialResolveCallCount += 1
        lastSocialResolveProvider = provider
        lastSocialResolveIdToken = idToken
        lastSocialResolveNonce = nonce
        lastSocialResolveDeviceId = deviceId
        return try socialResolveResult.get()
    }

    // socialRegister
    var socialRegisterResult: Result<SocialAuthResponse, Error> = .success(.stubAuthenticated())
    private(set) var socialRegisterCallCount = 0
    private(set) var lastSocialRegisterRequest: SocialRegisterRequest?
    func socialRegister(_ request: SocialRegisterRequest) async throws -> SocialAuthResponse {
        socialRegisterCallCount += 1
        lastSocialRegisterRequest = request
        return try socialRegisterResult.get()
    }

    // mfaSend
    var mfaSendResult: Result<MFASendResponse, Error> = .success(.stub())
    private(set) var mfaSendCallCount = 0
    private(set) var lastMFASendChallengeToken: String?
    func mfaSend(challengeToken: String) async throws -> MFASendResponse {
        mfaSendCallCount += 1
        lastMFASendChallengeToken = challengeToken
        return try mfaSendResult.get()
    }

    // mfaVerify
    var mfaVerifyResult: Result<MFAVerifyResponse, Error> = .success(.stub())
    private(set) var lastMFAVerifyChallengeToken: String?
    private(set) var lastMFAVerifyCode: String?
    func mfaVerify(challengeToken: String, code: String) async throws -> MFAVerifyResponse {
        lastMFAVerifyChallengeToken = challengeToken
        lastMFAVerifyCode = code
        return try mfaVerifyResult.get()
    }

    // forgotPassword
    var forgotPasswordResult: Result<ForgotPasswordResponse, Error> = .success(.stub())
    private(set) var lastForgotEmail: String?
    func forgotPassword(email: String) async throws -> ForgotPasswordResponse {
        lastForgotEmail = email
        return try forgotPasswordResult.get()
    }

    // verifyResetMFA
    var verifyResetMFAResult: Result<VerifyResetMFAResponse, Error> = .success(.stub())
    private(set) var lastVerifyResetEmail: String?
    private(set) var lastVerifyResetCode: String?
    func verifyResetMFA(email: String, code: String) async throws -> VerifyResetMFAResponse {
        lastVerifyResetEmail = email
        lastVerifyResetCode = code
        return try verifyResetMFAResult.get()
    }

    // resetPassword
    var resetPasswordResult: Result<ResetPasswordResponse, Error> = .success(.stub())
    private(set) var lastResetNewPassword: String?
    private(set) var lastResetToken: String?
    func resetPassword(newPassword: String, resetToken: String) async throws -> ResetPasswordResponse {
        lastResetNewPassword = newPassword
        lastResetToken = resetToken
        return try resetPasswordResult.get()
    }

    // signOut
    var signOutResult: Result<SignOutResponse, Error> = .success(.stub())
    private(set) var signOutCallCount = 0
    func signOut() async throws -> SignOutResponse {
        signOutCallCount += 1
        return try signOutResult.get()
    }

    // Not exercised by current tests.
    func registerResendCode(email: String) async throws -> ResendRegistrationCodeResponse {
        fatalError("registerResendCode not stubbed")
    }
    func refreshToken(refreshToken: String) async throws -> RefreshTokenResponse {
        fatalError("refreshToken not stubbed")
    }
}

// MARK: - MockOnboardingRepository

final class MockOnboardingRepository: OnboardingRepositoryProtocol {

    var saveDraftError: Error?
    private(set) var saveDraftCallCount = 0
    private(set) var lastSavedDraft: OnboardingDraft?
    private(set) var lastSavedPassword: String?
    func saveDraft(_ draft: OnboardingDraft, password: String?) async throws {
        saveDraftCallCount += 1
        lastSavedDraft = draft
        lastSavedPassword = password
        if let saveDraftError { throw saveDraftError }
    }

    var getDraftResult: Result<(draft: OnboardingDraft, password: String?)?, Error> = .success(nil)
    private(set) var getDraftCallCount = 0
    func getDraft() async throws -> (draft: OnboardingDraft, password: String?)? {
        getDraftCallCount += 1
        return try getDraftResult.get()
    }

    private(set) var clearDraftCallCount = 0
    var clearDraftError: Error?
    func clearDraft() async throws {
        clearDraftCallCount += 1
        if let clearDraftError { throw clearDraftError }
    }
}

// MARK: - MockKeychain

final class MockKeychain: KeychainManaging {
    var storage: [KeychainKey: String] = [:]

    func save(_ value: String, for key: KeychainKey) throws { storage[key] = value }
    func retrieve(for key: KeychainKey) throws -> String? { storage[key] }
    func delete(for key: KeychainKey) throws { storage[key] = nil }

    func saveAuthTokens(accessToken: String, refreshToken: String, userId: String, deviceId: String, firebaseToken: String?) throws {
        storage[.accessToken] = accessToken
        storage[.refreshToken] = refreshToken
        storage[.userId] = userId
        storage[.deviceId] = deviceId
        if let firebaseToken { storage[.firebaseToken] = firebaseToken }
    }

    func clearAuthData() throws {
        [.accessToken, .refreshToken, .userId, .firebaseToken, .fcmToken].forEach { storage[$0] = nil }
    }
}

// MARK: - MockSocialAuthProvider

@MainActor
final class MockSocialAuthProvider: SocialAuthProviding {
    var provider: AuthProvider = .google

    init(provider: AuthProvider = .google) {
        self.provider = provider
    }

    var signInResult: Result<SocialAccount, Error> = .success(.stub())
    private(set) var signInCallCount = 0
    func signIn() async throws -> SocialAccount {
        signInCallCount += 1
        return try signInResult.get()
    }

    var refreshedCredentialResult: Result<SocialCredential, Error> = .success(.stub())
    private(set) var refreshedCredentialCallCount = 0
    private(set) var lastRefreshedCredentialIdentity: SocialDraftIdentity?
    func refreshedCredential(matching identity: SocialDraftIdentity) async throws -> SocialCredential {
        refreshedCredentialCallCount += 1
        lastRefreshedCredentialIdentity = identity
        return try refreshedCredentialResult.get()
    }

    private(set) var signOutCallCount = 0
    func signOut() {
        signOutCallCount += 1
    }
}
