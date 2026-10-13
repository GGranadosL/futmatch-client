import XCTest
@testable import PlayerFeature

final class AuthorizeSensitiveActionUseCaseTests: XCTestCase {

    private func makeSUT(
        preferenceStore: MockPaymentSecurityPreferenceStore = MockPaymentSecurityPreferenceStore(),
        confirmIdentityUseCase: MockConfirmLocalIdentityUseCase = MockConfirmLocalIdentityUseCase()
    ) -> AuthorizeSensitiveActionUseCase {
        AuthorizeSensitiveActionUseCase(
            preferenceStore: preferenceStore,
            confirmIdentityUseCase: confirmIdentityUseCase
        )
    }

    func test_execute_whenToggleOff_doesNotCallIdentityUseCase() async throws {
        let store = MockPaymentSecurityPreferenceStore()
        store.isEnabled = false
        let identity = MockConfirmLocalIdentityUseCase()
        let sut = makeSUT(preferenceStore: store, confirmIdentityUseCase: identity)

        try await sut.execute(reason: "reason")

        XCTAssertEqual(identity.callCount, 0)
    }

    func test_execute_whenToggleOn_delegatesToIdentityUseCase_andPropagatesSuccess() async throws {
        let store = MockPaymentSecurityPreferenceStore()
        store.isEnabled = true
        let identity = MockConfirmLocalIdentityUseCase()
        let sut = makeSUT(preferenceStore: store, confirmIdentityUseCase: identity)

        try await sut.execute(reason: "reason")

        XCTAssertEqual(identity.callCount, 1)
        XCTAssertEqual(identity.lastReason, "reason")
    }

    func test_execute_whenToggleOn_andIdentityFails_propagatesFailure() async {
        let store = MockPaymentSecurityPreferenceStore()
        store.isEnabled = true
        let identity = MockConfirmLocalIdentityUseCase()
        identity.result = .failure(BiometricAuthError.failed)
        let sut = makeSUT(preferenceStore: store, confirmIdentityUseCase: identity)

        do {
            try await sut.execute(reason: "reason")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is BiometricAuthError)
        }
    }
}
