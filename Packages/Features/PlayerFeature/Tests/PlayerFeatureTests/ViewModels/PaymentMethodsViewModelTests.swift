import XCTest
@_spi(CustomerSessionBetaAccess) import StripePaymentSheet
@testable import PlayerFeature

@MainActor
final class PaymentMethodsViewModelTests: XCTestCase {

    private func makeSUT(service: MockPaymentService = MockPaymentService()) -> PaymentMethodsViewModel {
        PaymentMethodsViewModel(paymentService: service)
    }

    func test_open_fetchesSessionAndRequestsPresentation() async {
        let service = MockPaymentService()
        let sut = makeSUT(service: service)

        await sut.open()

        XCTAssertEqual(service.fetchCustomerSessionCallCount, 1)
        XCTAssertNotNil(sut.presentationRequest)
        XCTAssertNotNil(sut.customerSheet)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func test_open_repeatedTapsWhileLoading_fetchOnceAndRequestOnce() async {
        let service = MockPaymentService()
        let sut = makeSUT(service: service)
        var requests: [UUID] = []
        let cancellable = sut.$presentationRequest.compactMap { $0 }.sink { requests.append($0) }

        async let first: Void = sut.open()
        async let second: Void = sut.open()
        async let third: Void = sut.open()
        _ = await (first, second, third)

        XCTAssertEqual(service.fetchCustomerSessionCallCount, 1)
        XCTAssertEqual(requests.count, 1)
        cancellable.cancel()
    }

    func test_open_whenServiceFails_setsErrorAndStopsLoading() async {
        let service = MockPaymentService()
        service.fetchCustomerSessionResult = .failure(TestError.boom)
        let sut = makeSUT(service: service)

        await sut.open()

        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.error)
        XCTAssertNil(sut.presentationRequest)
    }

    func test_open_whileSheetIsPresented_isIgnored() async {
        let service = MockPaymentService()
        let sut = makeSUT(service: service)
        await sut.open()
        let firstRequest = sut.presentationRequest
        sut.presentationStarted()

        await sut.open()

        XCTAssertEqual(sut.presentationRequest, firstRequest)
        XCTAssertEqual(service.fetchCustomerSessionCallCount, 1)
    }

    func test_openAfterCancel_reusesSheetWithoutFetchingAgain() async {
        let service = MockPaymentService()
        let sut = makeSUT(service: service)
        await sut.open()
        let firstRequest = sut.presentationRequest
        sut.presentationStarted()
        sut.handleCustomerSheetResult(.canceled(nil))

        await sut.open()

        XCTAssertFalse(sut.isPresenting)
        XCTAssertNotEqual(sut.presentationRequest, firstRequest)
        XCTAssertEqual(service.fetchCustomerSessionCallCount, 1)
    }

    func test_openAfterSheetError_rebuildsSheet() async {
        let service = MockPaymentService()
        let sut = makeSUT(service: service)
        await sut.open()
        sut.presentationStarted()
        sut.handleCustomerSheetResult(.error(TestError.boom))
        XCTAssertFalse(sut.isPresenting)
        XCTAssertNil(sut.customerSheet)
        sut.clearError()

        await sut.open()

        XCTAssertEqual(service.fetchCustomerSessionCallCount, 2)
        XCTAssertNotNil(sut.customerSheet)
    }

    func test_presentationFailed_releasesStateAndShowsError() async {
        let sut = makeSUT()
        await sut.open()
        sut.presentationStarted()

        sut.presentationFailed()

        XCTAssertFalse(sut.isPresenting)
        XCTAssertEqual(sut.error, L10n.Settings.paymentMethodsOpenError)
    }
}
