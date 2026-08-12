import XCTest
import NetworkFramework
@testable import PlayerFeature

// MARK: - FetchPendingMatchPaymentUseCaseTests

final class FetchPendingMatchPaymentUseCaseTests: XCTestCase {

    private func makeSUT(
        service: MockPaymentService = MockPaymentService(),
        isDemoMode: Bool = false
    ) -> FetchPendingMatchPaymentUseCase {
        FetchPendingMatchPaymentUseCase(paymentService: service, isDemoMode: isDemoMode)
    }

    private func serverError(
        statusCode: Int,
        errorCode: String = "",
        message: String = ""
    ) -> APIError {
        .serverError(statusCode: statusCode, title: "", message: message, errorCode: errorCode)
    }

    // MARK: - Success

    func test_execute_completePayload_returnsRecovered() async {
        let service = MockPaymentService()
        let data = JoinMatchData.stub()
        service.fetchPendingMatchPaymentResult = .success(data)

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .recovered(data))
        XCTAssertEqual(service.lastPendingMatchId, "m1")
    }

    // MARK: - Incomplete payloads can't open PaymentSheet

    func test_execute_missingClientSecret_returnsNotRecoverable() async {
        let service = MockPaymentService()
        service.fetchPendingMatchPaymentResult = .success(.stub(clientSecret: nil))

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .notRecoverable(message: nil))
    }

    func test_execute_missingCustomerSessionClientSecret_returnsNotRecoverable() async {
        let service = MockPaymentService()
        service.fetchPendingMatchPaymentResult = .success(.stub(customerSessionClientSecret: nil))

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .notRecoverable(message: nil))
    }

    func test_execute_emptyPublishableKey_returnsNotRecoverable() async {
        let service = MockPaymentService()
        service.fetchPendingMatchPaymentResult = .success(.stub(publishableKey: ""))

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .notRecoverable(message: nil))
    }

    func test_execute_nilData_returnsNotRecoverable() async {
        let service = MockPaymentService()
        service.fetchPendingMatchPaymentResult = .success(nil)

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .notRecoverable(message: nil))
    }

    // MARK: - Error mapping

    func test_execute_409WithErrorCode_returnsNotRecoverableWithBackendMessage() async {
        let service = MockPaymentService()
        service.fetchPendingMatchPaymentResult = .failure(serverError(
            statusCode: 409,
            errorCode: "PAYMENT_PENDING_NOT_RECOVERABLE",
            message: "La reserva ya venció"
        ))

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .notRecoverable(message: "La reserva ya venció"))
    }

    func test_execute_errorCodeWinsOverStatusCode() async {
        // A backend that answers 500 but names the code must still be classified by the code.
        let service = MockPaymentService()
        service.fetchPendingMatchPaymentResult = .failure(serverError(
            statusCode: 500,
            errorCode: "PAYMENT_PENDING_NOT_RECOVERABLE"
        ))

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .notRecoverable(message: nil))
    }

    func test_execute_503_returnsRetryLater() async {
        let service = MockPaymentService()
        service.fetchPendingMatchPaymentResult = .failure(serverError(
            statusCode: 503,
            errorCode: "PAYMENT_FAILED",
            message: "Intenta más tarde"
        ))

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .retryLater(message: "Intenta más tarde"))
    }

    func test_execute_notFound_returnsNotRecoverable() async {
        // APIClient collapses 404 into `.notFound` and discards the body.
        let service = MockPaymentService()
        service.fetchPendingMatchPaymentResult = .failure(APIError.notFound)

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .notRecoverable(message: nil))
    }

    func test_execute_networkError_returnsUnavailable_soNoDialogFires() async {
        let service = MockPaymentService()
        service.fetchPendingMatchPaymentResult = .failure(APIError.networkError(URLError(.timedOut)))

        let result = await makeSUT(service: service).execute(matchId: "m1")

        XCTAssertEqual(result, .unavailable)
    }

    // MARK: - Demo mode

    func test_execute_demoMode_returnsUnavailableWithoutHittingNetwork() async {
        let service = MockPaymentService()

        let result = await makeSUT(service: service, isDemoMode: true).execute(matchId: "m1")

        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(service.fetchPendingMatchPaymentCallCount, 0)
    }
}
