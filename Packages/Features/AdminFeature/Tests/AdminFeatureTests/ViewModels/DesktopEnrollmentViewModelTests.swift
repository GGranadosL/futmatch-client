import XCTest
@testable import AdminFeature

@MainActor
final class DesktopEnrollmentViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(
        fetchDetailsUseCase: MockFetchDesktopEnrollmentDetailsUseCase = MockFetchDesktopEnrollmentDetailsUseCase(),
        approveUseCase: MockApproveDesktopEnrollmentUseCase = MockApproveDesktopEnrollmentUseCase()
    ) -> DesktopEnrollmentViewModel {
        DesktopEnrollmentViewModel(
            fetchDetailsUseCase: fetchDetailsUseCase,
            approveUseCase: approveUseCase
        )
    }

    // MARK: - Scanning

    func test_handleScan_movesToConfirmation_onSuccess() async {
        let fetch = MockFetchDesktopEnrollmentDetailsUseCase()
        fetch.result = .success(.stub())
        let sut = makeSUT(fetchDetailsUseCase: fetch)

        XCTAssertEqual(sut.state, .idle)
        await sut.handleScan(DesktopEnrollmentTicket.stubQRPayload())

        XCTAssertEqual(sut.state, .confirmation(.stub()))
        XCTAssertTrue(sut.isShowingConfirmation)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(fetch.callCount, 1)
    }

    func test_handleScan_scanningNeverApproves() async {
        let approve = MockApproveDesktopEnrollmentUseCase()
        let sut = makeSUT(approveUseCase: approve)

        await sut.handleScan(DesktopEnrollmentTicket.stubQRPayload())

        XCTAssertEqual(approve.callCount, 0, "A scan alone must never approve an enrollment")
        XCTAssertFalse(sut.didApprove)
    }

    func test_handleScan_invalidQR_setsErrorAndReturnsToIdle() async {
        let fetch = MockFetchDesktopEnrollmentDetailsUseCase()
        fetch.result = .failure(DesktopEnrollmentError.invalidQR)
        let sut = makeSUT(fetchDetailsUseCase: fetch)

        await sut.handleScan("whatever")

        XCTAssertEqual(sut.state, .idle, "Must return to idle so the admin can scan again")
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isShowingConfirmation)
    }

    func test_handleScan_isIgnored_whileAnotherScanIsBeingProcessed() async {
        let fetch = MockFetchDesktopEnrollmentDetailsUseCase()
        fetch.result = .success(.stub())
        let sut = makeSUT(fetchDetailsUseCase: fetch)

        // A code left in frame keeps firing; only the first one may act.
        await sut.handleScan(DesktopEnrollmentTicket.stubQRPayload())
        await sut.handleScan(DesktopEnrollmentTicket.stubQRPayload())

        XCTAssertEqual(fetch.callCount, 1)
    }

    func test_state_isBusy_pausesScannerOutsideIdle() async {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.isBusy)

        await sut.handleScan(DesktopEnrollmentTicket.stubQRPayload())

        XCTAssertTrue(sut.state.isBusy)
    }

    // MARK: - Approval

    func test_approve_setsDidApprove_andForwardsScannedTicket() async {
        let ticket = DesktopEnrollmentTicket.stub(
            enrollmentId: "0f8fad5b-d9cb-469f-a165-70867728950e",
            nonce: "7c9e6679-7425-40de-944b-e07fc1f90ae7"
        )
        let fetch = MockFetchDesktopEnrollmentDetailsUseCase()
        fetch.result = .success(.stub(ticket: ticket))
        let approve = MockApproveDesktopEnrollmentUseCase()
        let sut = makeSUT(fetchDetailsUseCase: fetch, approveUseCase: approve)

        await sut.handleScan(DesktopEnrollmentTicket.stubQRPayload())
        await sut.approve()

        XCTAssertTrue(sut.didApprove)
        XCTAssertEqual(approve.callCount, 1)
        XCTAssertEqual(approve.lastTicket, ticket)
        XCTAssertNil(sut.sheetErrorMessage)
    }

    func test_approve_onFailure_staysOnConfirmationWithSheetError() async {
        let approve = MockApproveDesktopEnrollmentUseCase()
        approve.result = .failure(TestError.boom)
        let sut = makeSUT(approveUseCase: approve)

        await sut.handleScan(DesktopEnrollmentTicket.stubQRPayload())
        await sut.approve()

        XCTAssertFalse(sut.didApprove)
        XCTAssertEqual(sut.state, .confirmation(.stub()), "The sheet must stay open so the admin can retry")
        XCTAssertNotNil(sut.sheetErrorMessage)
    }

    func test_approve_isIgnored_whenNoEnrollmentIsPending() async {
        let approve = MockApproveDesktopEnrollmentUseCase()
        let sut = makeSUT(approveUseCase: approve)

        await sut.approve()

        XCTAssertEqual(approve.callCount, 0)
    }

    // MARK: - Cancellation

    func test_cancelConfirmation_returnsToIdleWithoutApproving() async {
        let approve = MockApproveDesktopEnrollmentUseCase()
        let sut = makeSUT(approveUseCase: approve)

        await sut.handleScan(DesktopEnrollmentTicket.stubQRPayload())
        sut.cancelConfirmation()

        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(approve.callCount, 0, "Dismissing must make no backend request")
        XCTAssertFalse(sut.didApprove)
    }
}
