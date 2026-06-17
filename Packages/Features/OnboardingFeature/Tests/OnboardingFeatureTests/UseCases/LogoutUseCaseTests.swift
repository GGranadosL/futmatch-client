import XCTest
import PersistenceFramework
@testable import OnboardingFeature

final class LogoutUseCaseTests: XCTestCase {

    func test_execute_callsSignOut_andClearsAuthData() async throws {
        let auth = MockAuthService()
        let keychain = MockKeychain()
        keychain.storage[.accessToken] = "access"
        keychain.storage[.refreshToken] = "refresh"
        let sut = LogoutUseCase(authService: auth, keychainManager: keychain)

        try await sut.execute()

        XCTAssertEqual(auth.signOutCallCount, 1)
        XCTAssertNil(keychain.storage[.accessToken])
        XCTAssertNil(keychain.storage[.refreshToken])
    }

    func test_execute_signOutFails_propagatesError_andKeepsTokens() async {
        let auth = MockAuthService()
        auth.signOutResult = .failure(TestError.boom)
        let keychain = MockKeychain()
        keychain.storage[.accessToken] = "access"
        let sut = LogoutUseCase(authService: auth, keychainManager: keychain)

        do {
            try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
        // clearAuthData runs only after a successful signOut.
        XCTAssertEqual(keychain.storage[.accessToken], "access")
    }
}
