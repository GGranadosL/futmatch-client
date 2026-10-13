import XCTest
@testable import OnboardingFeature

/// The rules every code-entry screen now derives its state from.
final class MFACodeWindowTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func test_init_turnsBackendDurationsIntoAbsoluteDates() {
        let window = MFACodeWindow(expiresInSeconds: 300, resendCodeTimeInSeconds: 60, now: t0)

        XCTAssertEqual(window.codeExpiresAt, t0.addingTimeInterval(300))
        XCTAssertEqual(window.resendAvailableAt, t0.addingTimeInterval(60))
    }

    func test_isCodeExpired_onlyOnceTheDeadlineHasPassed() {
        let window = MFACodeWindow(expiresInSeconds: 300, resendCodeTimeInSeconds: 60, now: t0)

        XCTAssertFalse(window.isCodeExpired(at: t0))
        XCTAssertFalse(window.isCodeExpired(at: t0.addingTimeInterval(299)))
        XCTAssertTrue(window.isCodeExpired(at: t0.addingTimeInterval(300)))
        XCTAssertTrue(window.isCodeExpired(at: t0.addingTimeInterval(1_000)))
    }

    func test_canResend_afterTheCooldown() {
        let window = MFACodeWindow(expiresInSeconds: 300, resendCodeTimeInSeconds: 60, now: t0)

        XCTAssertFalse(window.canResend(at: t0))
        XCTAssertFalse(window.canResend(at: t0.addingTimeInterval(59)))
        XCTAssertTrue(window.canResend(at: t0.addingTimeInterval(60)))
    }

    /// An expired code must always leave something to press, whatever the cooldown
    /// says — otherwise the screen is a dead end.
    func test_canResend_whenCodeExpiredEvenIfCooldownHasNotElapsed() {
        let window = MFACodeWindow(expiresInSeconds: 30, resendCodeTimeInSeconds: 600, now: t0)

        XCTAssertFalse(window.canResend(at: t0.addingTimeInterval(29)))
        XCTAssertTrue(window.canResend(at: t0.addingTimeInterval(30)))
    }

    func test_secondsUntilResend_countsDownAndFloorsAtZero() {
        let window = MFACodeWindow(expiresInSeconds: 300, resendCodeTimeInSeconds: 60, now: t0)

        XCTAssertEqual(window.secondsUntilResend(at: t0), 60)
        XCTAssertEqual(window.secondsUntilResend(at: t0.addingTimeInterval(30)), 30)
        XCTAssertEqual(window.secondsUntilResend(at: t0.addingTimeInterval(60)), 0)
        XCTAssertEqual(window.secondsUntilResend(at: t0.addingTimeInterval(120)), 0)
    }

    func test_secondsUntilExpiry_countsDownAndFloorsAtZero() {
        let window = MFACodeWindow(expiresInSeconds: 300, resendCodeTimeInSeconds: 60, now: t0)

        XCTAssertEqual(window.secondsUntilExpiry(at: t0), 300)
        XCTAssertEqual(window.secondsUntilExpiry(at: t0.addingTimeInterval(299)), 1)
        XCTAssertEqual(window.secondsUntilExpiry(at: t0.addingTimeInterval(400)), 0)
    }

    /// A backend that reports nonsense must not produce a window that reads as
    /// "expires in the past", which would make the code unusable on arrival.
    func test_negativeDurationsAreClampedToZero() {
        let window = MFACodeWindow(expiresInSeconds: -10, resendCodeTimeInSeconds: -10, now: t0)

        XCTAssertEqual(window.codeExpiresAt, t0)
        XCTAssertEqual(window.resendAvailableAt, t0)
        XCTAssertTrue(window.isCodeExpired(at: t0))
        XCTAssertTrue(window.canResend(at: t0))
    }
}
