import XCTest
@testable import PlayerFeature

final class FetchPaymentHistoryUseCaseTests: XCTestCase {

    func test_execute_returnsServiceHistory() async throws {
        let service = MockPaymentService()
        let expected = [PaymentHistoryItem.stub(id: "ph-1"), PaymentHistoryItem.stub(id: "ph-2")]
        service.fetchPaymentHistoryResult = .success(expected)
        let sut = FetchPaymentHistoryUseCase(paymentService: service)

        let result = try await sut.execute()

        XCTAssertEqual(service.fetchPaymentHistoryCallCount, 1)
        XCTAssertEqual(result.map(\.id), ["ph-1", "ph-2"])
    }

    func test_execute_propagatesServiceError() async {
        let service = MockPaymentService()
        service.fetchPaymentHistoryResult = .failure(TestError.boom)
        let sut = FetchPaymentHistoryUseCase(paymentService: service)

        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
