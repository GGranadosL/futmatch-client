import XCTest
@testable import PlayerFeature

final class PollPaymentStatusUseCaseTests: XCTestCase {

    // Small interval / single attempt keeps tests fast (there is a fixed ~1.5s
    // initial delay inside the use case before the first poll).

    func test_finalSuccess_returnsSuccess() async {
        let payment = MockPaymentService()
        payment.pollPaymentStatusResult = .success(.stub(isFinal: true, isSuccess: true))
        let sut = PollPaymentStatusUseCase(paymentService: payment)

        let result = await sut.execute(matchId: "m-1", intervalSeconds: 0.01, maxAttempts: 3)

        assert(result, is: .success)
        XCTAssertEqual(payment.pollPaymentStatusCallCount, 1)
        XCTAssertEqual(payment.lastPollMatchId, "m-1")
        XCTAssertEqual(payment.fetchPaymentStatusCallCount, 0)
    }

    func test_finalNotSuccess_returnsFailure() async {
        let payment = MockPaymentService()
        payment.pollPaymentStatusResult = .success(.stub(status: "CANCELED", isFinal: true, isSuccess: false))
        let sut = PollPaymentStatusUseCase(paymentService: payment)

        let result = await sut.execute(matchId: "m-1", intervalSeconds: 0.01, maxAttempts: 3)

        assert(result, is: .failure)
    }

    func test_pollNeverFinal_exhausts_thenFallsBackToStatus_succeeded() async {
        let payment = MockPaymentService()
        payment.pollPaymentStatusResult = .success(nil)               // no active payment → keep polling
        payment.fetchPaymentStatusResult = .success(.stub(status: "SUCCEEDED"))
        let sut = PollPaymentStatusUseCase(paymentService: payment)

        let result = await sut.execute(matchId: "m-1", intervalSeconds: 0.01, maxAttempts: 1)

        assert(result, is: .success)
        XCTAssertEqual(payment.fetchPaymentStatusCallCount, 1)
        XCTAssertEqual(payment.lastStatusMatchId, "m-1")
    }

    func test_fallbackStatus_canceled_returnsFailure() async {
        let payment = MockPaymentService()
        payment.pollPaymentStatusResult = .success(nil)
        payment.fetchPaymentStatusResult = .success(.stub(status: "CANCELED"))
        let sut = PollPaymentStatusUseCase(paymentService: payment)

        let result = await sut.execute(matchId: "m-1", intervalSeconds: 0.01, maxAttempts: 1)

        assert(result, is: .failure)
    }

    func test_fallbackStatus_nonTerminal_returnsTimeout() async {
        let payment = MockPaymentService()
        payment.pollPaymentStatusResult = .success(nil)
        payment.fetchPaymentStatusResult = .success(.stub(status: "CREATED"))
        let sut = PollPaymentStatusUseCase(paymentService: payment)

        let result = await sut.execute(matchId: "m-1", intervalSeconds: 0.01, maxAttempts: 1)

        assert(result, is: .timeout)
    }

    // MARK: - Helper (PaymentPollResult is not Equatable)

    private func assert(
        _ result: PaymentPollResult,
        is expected: PaymentPollResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (result, expected) {
        case (.success, .success), (.failure, .failure), (.timeout, .timeout):
            break
        default:
            XCTFail("Expected \(expected), got \(result)", file: file, line: line)
        }
    }
}
