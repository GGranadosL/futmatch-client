import XCTest
import PersistenceFramework
@testable import OnboardingFeature

final class VerifyCodeUseCaseTests: XCTestCase {

    func test_execute_successCode_savesTokens_andReturnsResult() async throws {
        let auth = MockAuthService()
        auth.registerCompleteResult = .success(.stub(userId: "u-3", deviceId: "d-3", authCode: "SUCCESS"))
        let keychain = MockKeychain()
        let sut = VerifyCodeUseCase(authService: auth, keychainManager: keychain)

        let result = try await sut.execute(email: "a@b.com", code: "999")

        XCTAssertEqual(auth.lastRegisterCompleteEmail, "a@b.com")
        XCTAssertEqual(auth.lastRegisterCompleteCode, "999")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.userId, "u-3")
        XCTAssertEqual(keychain.storage[.accessToken], "access")
    }

    func test_execute_nonSuccessCode_throwsInvalidCode_andSkipsTokenSave() async {
        let auth = MockAuthService()
        auth.registerCompleteResult = .success(.stub(authCode: "INVALID"))
        let keychain = MockKeychain()
        let sut = VerifyCodeUseCase(authService: auth, keychainManager: keychain)

        do {
            _ = try await sut.execute(email: "a@b.com", code: "000")
            XCTFail("Expected invalidCode")
        } catch {
            guard case VerifyCodeError.invalidCode = error else {
                return XCTFail("Expected .invalidCode, got \(error)")
            }
        }
        XCTAssertNil(keychain.storage[.accessToken])
    }

    func test_execute_propagatesServiceError() async {
        let auth = MockAuthService()
        auth.registerCompleteResult = .failure(TestError.boom)
        let sut = VerifyCodeUseCase(authService: auth, keychainManager: MockKeychain())

        do {
            _ = try await sut.execute(email: "a@b.com", code: "1")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
