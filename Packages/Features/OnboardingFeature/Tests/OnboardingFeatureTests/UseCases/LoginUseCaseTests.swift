import XCTest
import PersistenceFramework
@testable import OnboardingFeature

final class LoginUseCaseTests: XCTestCase {

    // MARK: - execute

    func test_execute_noMFA_savesTokens_andReturnsResult() async throws {
        let auth = MockAuthService()
        auth.signInResult = .success(.stub(userId: "u-9", deviceId: "d-9", authCode: "SUCCESS", withTokens: true))
        let keychain = MockKeychain()
        let sut = LoginUseCase(authService: auth, keychainManager: keychain)

        let result = try await sut.execute(email: "a@b.com", password: "pw")

        XCTAssertEqual(auth.signInCallCount, 1)
        XCTAssertEqual(auth.lastSignInEmail, "a@b.com")
        XCTAssertFalse(result.requiresMFA)
        XCTAssertEqual(result.userId, "u-9")
        XCTAssertEqual(keychain.storage[.accessToken], "access")
        XCTAssertEqual(auth.mfaSendCallCount, 0)
    }

    func test_execute_mfaRequired_sendsCode_doesNotSaveTokens() async throws {
        let auth = MockAuthService()
        auth.signInResult = .success(.stub(authCode: "SUCCESS_NEED_MFA", withTokens: false))
        auth.mfaSendResult = .success(.stub(resendCodeTimeInSeconds: 45))
        let keychain = MockKeychain()
        let sut = LoginUseCase(authService: auth, keychainManager: keychain)

        let result = try await sut.execute(email: "a@b.com", password: "pw")

        XCTAssertTrue(result.requiresMFA)
        XCTAssertEqual(result.resendCodeTimeInSeconds, 45)
        XCTAssertEqual(auth.mfaSendCallCount, 1)
        XCTAssertNil(keychain.storage[.accessToken])
    }

    func test_execute_noMFA_missingTokens_throwsInvalidCredentials() async {
        let auth = MockAuthService()
        auth.signInResult = .success(.stub(authCode: "SUCCESS", withTokens: false))
        let sut = LoginUseCase(authService: auth, keychainManager: MockKeychain())

        do {
            _ = try await sut.execute(email: "a@b.com", password: "pw")
            XCTFail("Expected invalidCredentials")
        } catch {
            guard case AuthError.invalidCredentials = error else {
                return XCTFail("Expected .invalidCredentials, got \(error)")
            }
        }
    }

    func test_execute_forwardsExistingDeviceIdFromKeychain() async throws {
        let auth = MockAuthService()
        let keychain = MockKeychain()
        keychain.storage[.deviceId] = "existing-device"
        let sut = LoginUseCase(authService: auth, keychainManager: keychain)

        _ = try await sut.execute(email: "a@b.com", password: "pw")

        XCTAssertEqual(auth.lastSignInDeviceId, "existing-device")
    }

    func test_execute_propagatesServiceError() async {
        let auth = MockAuthService()
        auth.signInResult = .failure(TestError.boom)
        let sut = LoginUseCase(authService: auth, keychainManager: MockKeychain())

        do {
            _ = try await sut.execute(email: "a@b.com", password: "pw")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }

    // MARK: - sendMFACode

    func test_sendMFACode_returnsMappedResult() async throws {
        let auth = MockAuthService()
        auth.mfaSendResult = .success(.stub(newCodeSent: true, expiresInSeconds: 200, resendCodeTimeInSeconds: 60))
        let sut = LoginUseCase(authService: auth, keychainManager: MockKeychain())

        let result = try await sut.sendMFACode(userId: "u-1", deviceId: "d-1")

        XCTAssertTrue(result.newCodeSent)
        XCTAssertEqual(result.expiresInSeconds, 200)
        XCTAssertEqual(result.resendCodeTimeInSeconds, 60)
    }

    // MARK: - verifyMFACode

    func test_verifyMFACode_savesTokens_andReturnsResult() async throws {
        let auth = MockAuthService()
        auth.mfaVerifyResult = .success(.stub(userId: "u-7", deviceId: "d-7"))
        let keychain = MockKeychain()
        let sut = LoginUseCase(authService: auth, keychainManager: keychain)

        let result = try await sut.verifyMFACode(userId: "u-7", deviceId: "d-7", code: "123456")

        XCTAssertEqual(auth.lastMFAVerifyCode, "123456")
        XCTAssertFalse(result.requiresMFA)
        XCTAssertEqual(result.userId, "u-7")
        XCTAssertEqual(keychain.storage[.accessToken], "access")
    }
}
