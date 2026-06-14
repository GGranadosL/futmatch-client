import XCTest
@testable import PlayerFeature

final class FetchCustomerSessionUseCaseTests: XCTestCase {

    func test_execute_returnsServiceSession() async throws {
        let service = MockPaymentService()
        let expected = CustomerSessionData.stub(customerId: "cus_42")
        service.fetchCustomerSessionResult = .success(expected)
        let sut = FetchCustomerSessionUseCase(paymentService: service)

        let result = try await sut.execute()

        XCTAssertEqual(service.fetchCustomerSessionCallCount, 1)
        XCTAssertEqual(result.customerId, "cus_42")
    }

    func test_execute_propagatesServiceError() async {
        let service = MockPaymentService()
        service.fetchCustomerSessionResult = .failure(TestError.boom)
        let sut = FetchCustomerSessionUseCase(paymentService: service)

        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
