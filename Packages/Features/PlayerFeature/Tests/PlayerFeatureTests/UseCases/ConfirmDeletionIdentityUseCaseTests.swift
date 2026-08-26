import XCTest
@testable import PlayerFeature

final class ConfirmDeletionIdentityUseCaseTests: XCTestCase {

    func test_execute_whenUnavailable_doesNotPrompt() async throws {
        let authenticator = MockBiometricAuthenticator()
        authenticator.available = false
        let sut = ConfirmDeletionIdentityUseCase(authenticator: authenticator)

        try await sut.execute(reason: "reason")

        XCTAssertEqual(authenticator.authenticateCallCount, 0)
    }

    func test_execute_whenAvailable_promptsAndSucceeds() async throws {
        let authenticator = MockBiometricAuthenticator()
        authenticator.available = true
        let sut = ConfirmDeletionIdentityUseCase(authenticator: authenticator)

        try await sut.execute(reason: "reason")

        XCTAssertEqual(authenticator.authenticateCallCount, 1)
        XCTAssertEqual(authenticator.lastReason, "reason")
    }

    func test_execute_whenAuthenticationFails_propagatesError() async {
        let authenticator = MockBiometricAuthenticator()
        authenticator.available = true
        authenticator.authenticateResult = .failure(BiometricAuthError.failed)
        let sut = ConfirmDeletionIdentityUseCase(authenticator: authenticator)

        do {
            try await sut.execute(reason: "reason")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is BiometricAuthError)
        }
    }
}

// MARK: - MockBiometricAuthenticator

final class MockBiometricAuthenticator: BiometricAuthenticating {
    var available = true
    var authenticateResult: Result<Void, Error> = .success(())
    private(set) var authenticateCallCount = 0
    private(set) var lastReason: String?

    func isAvailable() -> Bool { available }

    func authenticate(reason: String) async throws {
        authenticateCallCount += 1
        lastReason = reason
        try authenticateResult.get()
    }
}
