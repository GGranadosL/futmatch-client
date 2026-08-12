import XCTest
@testable import AdminFeature

// MARK: - FetchDesktopEnrollmentDetailsUseCase

final class FetchDesktopEnrollmentDetailsUseCaseTests: XCTestCase {

    func test_execute_returnsTicketAndServerDetails() async throws {
        let repo = MockDesktopEnrollmentRepository()
        repo.fetchDetailsResult = .success(.stub())
        let sut = FetchDesktopEnrollmentDetailsUseCase(repository: repo)

        let enrollment = try await sut.execute(qrPayload: DesktopEnrollmentTicket.stubQRPayload())

        XCTAssertEqual(repo.fetchDetailsCallCount, 1)
        XCTAssertEqual(repo.lastFetchedTicket, .stub())
        XCTAssertEqual(enrollment.ticket, .stub())
        XCTAssertEqual(enrollment.details, .stub())
    }

    func test_execute_keepsNilDetails_whenBackendOmitsThem() async throws {
        // Enrollments from older desktop builds carry no metadata; the use case
        // must pass the absence through rather than substituting anything.
        let repo = MockDesktopEnrollmentRepository()
        repo.fetchDetailsResult = .success(
            DesktopEnrollmentDetails(deviceInfo: nil, appVersion: nil, osVersion: nil)
        )
        let sut = FetchDesktopEnrollmentDetailsUseCase(repository: repo)

        let enrollment = try await sut.execute(qrPayload: DesktopEnrollmentTicket.stubQRPayload())

        XCTAssertNil(enrollment.details.deviceInfo)
        XCTAssertNil(enrollment.details.appVersion)
        XCTAssertNil(enrollment.details.osVersion)
    }

    func test_execute_throwsInvalidQR_andSkipsNetwork_forUnrelatedPayload() async {
        let repo = MockDesktopEnrollmentRepository()
        let sut = FetchDesktopEnrollmentDetailsUseCase(repository: repo)

        do {
            _ = try await sut.execute(qrPayload: "https://example.com")
            XCTFail("Expected invalidQR error")
        } catch {
            XCTAssertEqual(error as? DesktopEnrollmentError, .invalidQR)
        }
        XCTAssertEqual(repo.fetchDetailsCallCount, 0, "A junk scan must not reach the network")
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockDesktopEnrollmentRepository()
        repo.fetchDetailsResult = .failure(TestError.boom)
        let sut = FetchDesktopEnrollmentDetailsUseCase(repository: repo)

        do {
            _ = try await sut.execute(qrPayload: DesktopEnrollmentTicket.stubQRPayload())
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}

// MARK: - ApproveDesktopEnrollmentUseCase

final class ApproveDesktopEnrollmentUseCaseTests: XCTestCase {

    func test_execute_forwardsTicketToRepository() async throws {
        let repo = MockDesktopEnrollmentRepository()
        let sut = ApproveDesktopEnrollmentUseCase(repository: repo)

        try await sut.execute(ticket: .stub())

        XCTAssertEqual(repo.approveCallCount, 1)
        XCTAssertEqual(repo.lastApprovedTicket, .stub())
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockDesktopEnrollmentRepository()
        repo.approveResult = .failure(TestError.boom)
        let sut = ApproveDesktopEnrollmentUseCase(repository: repo)

        do {
            try await sut.execute(ticket: .stub())
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
