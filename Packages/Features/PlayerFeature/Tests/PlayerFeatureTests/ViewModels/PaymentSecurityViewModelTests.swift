import XCTest
@testable import PlayerFeature

@MainActor
final class PaymentSecurityViewModelTests: XCTestCase {

    private func makeSUT(
        getEnabledUseCase: MockGetPaymentSecurityEnabledUseCase = MockGetPaymentSecurityEnabledUseCase(),
        setEnabledUseCase: MockSetPaymentSecurityEnabledUseCase = MockSetPaymentSecurityEnabledUseCase(),
        authorizeUseCase: MockAuthorizeSensitiveActionUseCase = MockAuthorizeSensitiveActionUseCase()
    ) -> PaymentSecurityViewModel {
        PaymentSecurityViewModel(
            getEnabledUseCase: getEnabledUseCase,
            setEnabledUseCase: setEnabledUseCase,
            authorizeUseCase: authorizeUseCase
        )
    }

    func test_load_readsFromGetUseCase() {
        let getUseCase = MockGetPaymentSecurityEnabledUseCase()
        getUseCase.result = false
        let sut = makeSUT(getEnabledUseCase: getUseCase)

        sut.load()

        XCTAssertFalse(sut.isEnabled)
        XCTAssertEqual(getUseCase.callCount, 1)
    }

    func test_enable_neverCallsAuthorizeUseCase_andPersistsTrueImmediately() {
        let setUseCase = MockSetPaymentSecurityEnabledUseCase()
        let authorize = MockAuthorizeSensitiveActionUseCase()
        let sut = makeSUT(setEnabledUseCase: setUseCase, authorizeUseCase: authorize)

        sut.enable()

        XCTAssertTrue(sut.isEnabled)
        XCTAssertEqual(setUseCase.callCount, 1)
        XCTAssertEqual(setUseCase.lastValue, true)
        XCTAssertEqual(authorize.callCount, 0)
    }

    func test_disable_whenAuthorizeSucceeds_persistsFalse_andSetsIsEnabledFalse() async {
        let setUseCase = MockSetPaymentSecurityEnabledUseCase()
        let authorize = MockAuthorizeSensitiveActionUseCase()
        let sut = makeSUT(setEnabledUseCase: setUseCase, authorizeUseCase: authorize)

        await sut.disable()

        XCTAssertFalse(sut.isEnabled)
        XCTAssertEqual(setUseCase.callCount, 1)
        XCTAssertEqual(setUseCase.lastValue, false)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isVerifying)
    }

    func test_disable_whenAuthorizeFails_leavesIsEnabledTrue_andSetsErrorMessage() async {
        let setUseCase = MockSetPaymentSecurityEnabledUseCase()
        let authorize = MockAuthorizeSensitiveActionUseCase()
        authorize.result = .failure(BiometricAuthError.failed)
        let sut = makeSUT(setEnabledUseCase: setUseCase, authorizeUseCase: authorize)

        await sut.disable()

        XCTAssertTrue(sut.isEnabled)
        XCTAssertEqual(setUseCase.callCount, 0)
        XCTAssertEqual(sut.errorMessage, L10n.Settings.paymentSecurityBiometricFailedError)
        XCTAssertFalse(sut.isVerifying)
    }
}
