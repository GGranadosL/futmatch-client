import XCTest
@testable import PlayerFeature

final class ConfirmLocalIdentityUseCaseTests: XCTestCase {

    func test_execute_whenUnavailable_doesNotPrompt() async throws {
        let authenticator = MockBiometricAuthenticator()
        authenticator.available = false
        let sut = ConfirmLocalIdentityUseCase(authenticator: authenticator)

        try await sut.execute(reason: "reason")

        XCTAssertEqual(authenticator.authenticateCallCount, 0)
    }

    func test_execute_whenAvailable_promptsAndSucceeds() async throws {
        let authenticator = MockBiometricAuthenticator()
        authenticator.available = true
        let sut = ConfirmLocalIdentityUseCase(authenticator: authenticator)

        try await sut.execute(reason: "reason")

        XCTAssertEqual(authenticator.authenticateCallCount, 1)
        XCTAssertEqual(authenticator.lastReason, "reason")
    }

    func test_execute_whenAuthenticationFails_propagatesError() async {
        let authenticator = MockBiometricAuthenticator()
        authenticator.available = true
        authenticator.authenticateResult = .failure(BiometricAuthError.failed)
        let sut = ConfirmLocalIdentityUseCase(authenticator: authenticator)

        do {
            try await sut.execute(reason: "reason")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is BiometricAuthError)
        }
    }

    func test_execute_whenNotPermitted_failsOpen() async throws {
        let authenticator = MockBiometricAuthenticator()
        authenticator.available = true
        authenticator.authenticateResult = .failure(BiometricAuthError.notPermitted)
        let sut = ConfirmLocalIdentityUseCase(authenticator: authenticator)

        try await sut.execute(reason: "reason")

        XCTAssertEqual(authenticator.authenticateCallCount, 1)
    }
}
