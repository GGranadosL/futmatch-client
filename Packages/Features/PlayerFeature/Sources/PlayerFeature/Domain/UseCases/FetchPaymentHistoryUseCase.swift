import Foundation

// MARK: - Protocol

protocol FetchPaymentHistoryUseCaseProtocol {
    func execute() async throws -> [PaymentHistoryItem]
}

// MARK: - Implementation

final class FetchPaymentHistoryUseCase: FetchPaymentHistoryUseCaseProtocol {
    private let paymentService: PaymentServiceProtocol

    init(paymentService: PaymentServiceProtocol) {
        self.paymentService = paymentService
    }

    func execute() async throws -> [PaymentHistoryItem] {
        try await paymentService.fetchPaymentHistory()
    }
}
