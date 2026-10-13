import Foundation

public protocol GetPaymentSecurityEnabledUseCaseProtocol {
    func execute() -> Bool
}

public struct GetPaymentSecurityEnabledUseCase: GetPaymentSecurityEnabledUseCaseProtocol {
    private let store: PaymentSecurityPreferenceStoring

    init(store: PaymentSecurityPreferenceStoring) {
        self.store = store
    }

    public func execute() -> Bool {
        store.isEnabled
    }
}
