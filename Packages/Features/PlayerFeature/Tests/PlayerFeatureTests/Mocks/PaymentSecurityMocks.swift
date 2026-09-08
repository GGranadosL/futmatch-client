import Foundation
@testable import PlayerFeature

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

// MARK: - MockConfirmLocalIdentityUseCase

final class MockConfirmLocalIdentityUseCase: ConfirmLocalIdentityUseCaseProtocol {
    var result: Result<Void, Error> = .success(())
    private(set) var callCount = 0
    private(set) var lastReason: String?

    func execute(reason: String) async throws {
        callCount += 1
        lastReason = reason
        try result.get()
    }
}

// MARK: - MockAuthorizeSensitiveActionUseCase

final class MockAuthorizeSensitiveActionUseCase: AuthorizeSensitiveActionUseCaseProtocol {
    var result: Result<Void, Error> = .success(())
    private(set) var callCount = 0
    private(set) var lastReason: String?

    func execute(reason: String) async throws {
        callCount += 1
        lastReason = reason
        try result.get()
    }
}

// MARK: - MockPaymentSecurityPreferenceStore

final class MockPaymentSecurityPreferenceStore: PaymentSecurityPreferenceStoring {
    var isEnabled = true
    private(set) var setEnabledCallCount = 0
    private(set) var lastSetValue: Bool?

    func setEnabled(_ enabled: Bool) {
        setEnabledCallCount += 1
        lastSetValue = enabled
        isEnabled = enabled
    }
}

// MARK: - MockGetPaymentSecurityEnabledUseCase

final class MockGetPaymentSecurityEnabledUseCase: GetPaymentSecurityEnabledUseCaseProtocol {
    var result = true
    private(set) var callCount = 0

    func execute() -> Bool {
        callCount += 1
        return result
    }
}

// MARK: - MockSetPaymentSecurityEnabledUseCase

final class MockSetPaymentSecurityEnabledUseCase: SetPaymentSecurityEnabledUseCaseProtocol {
    private(set) var callCount = 0
    private(set) var lastValue: Bool?

    func execute(_ enabled: Bool) {
        callCount += 1
        lastValue = enabled
    }
}
