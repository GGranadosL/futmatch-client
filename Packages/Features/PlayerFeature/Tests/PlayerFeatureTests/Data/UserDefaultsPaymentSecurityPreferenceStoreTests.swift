import XCTest
@testable import PlayerFeature

final class UserDefaultsPaymentSecurityPreferenceStoreTests: XCTestCase {

    private func makeSUT() -> UserDefaultsPaymentSecurityPreferenceStore {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return UserDefaultsPaymentSecurityPreferenceStore(defaults: defaults)
    }

    func test_isEnabled_whenNeverSet_defaultsTrue() {
        let sut = makeSUT()

        XCTAssertTrue(sut.isEnabled)
    }

    func test_isEnabled_afterSetEnabledFalse_readsFalse() {
        let sut = makeSUT()

        sut.setEnabled(false)

        XCTAssertFalse(sut.isEnabled)
    }

    func test_isEnabled_afterSetEnabledTrue_readsTrue() {
        let sut = makeSUT()
        sut.setEnabled(false)

        sut.setEnabled(true)

        XCTAssertTrue(sut.isEnabled)
    }
}
