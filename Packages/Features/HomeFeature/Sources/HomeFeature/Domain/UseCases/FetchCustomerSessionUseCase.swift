import Foundation

// MARK: - Protocol

protocol FetchCustomerSessionUseCaseProtocol {
    func execute() async throws -> CustomerSessionData
}

// MARK: - Implementation

final class FetchCustomerSessionUseCase: FetchCustomerSessionUseCaseProtocol {
    private let paymentService: PaymentServiceProtocol

    init(paymentService: PaymentServiceProtocol) {
        self.paymentService = paymentService
    }

    func execute() async throws -> CustomerSessionData {
        try await paymentService.fetchCustomerSession()
    }
}
