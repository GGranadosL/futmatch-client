import Foundation

public protocol SetPaymentSecurityEnabledUseCaseProtocol {
    func execute(_ enabled: Bool)
}

public struct SetPaymentSecurityEnabledUseCase: SetPaymentSecurityEnabledUseCaseProtocol {
    private let store: PaymentSecurityPreferenceStoring

    init(store: PaymentSecurityPreferenceStoring) {
        self.store = store
    }

    public func execute(_ enabled: Bool) {
        store.setEnabled(enabled)
    }
}
