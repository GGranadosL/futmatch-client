import Foundation
@testable import AdminFeature

// MARK: - MockDesktopEnrollmentRepository

final class MockDesktopEnrollmentRepository: DesktopEnrollmentRepositoryProtocol {
    var fetchDetailsResult: Result<DesktopEnrollmentDetails, Error> = .success(
        DesktopEnrollmentDetails(deviceInfo: nil, appVersion: nil, osVersion: nil)
    )
    var approveResult: Result<Void, Error> = .success(())

    private(set) var fetchDetailsCallCount = 0
    private(set) var approveCallCount = 0
    private(set) var lastFetchedTicket: DesktopEnrollmentTicket?
    private(set) var lastApprovedTicket: DesktopEnrollmentTicket?

    func fetchDetails(ticket: DesktopEnrollmentTicket) async throws -> DesktopEnrollmentDetails {
        fetchDetailsCallCount += 1
        lastFetchedTicket = ticket
        return try fetchDetailsResult.get()
    }

    func approve(ticket: DesktopEnrollmentTicket) async throws {
        approveCallCount += 1
        lastApprovedTicket = ticket
        try approveResult.get()
    }
}

// MARK: - MockFetchDesktopEnrollmentDetailsUseCase

final class MockFetchDesktopEnrollmentDetailsUseCase: FetchDesktopEnrollmentDetailsUseCaseProtocol {
    var result: Result<DesktopEnrollment, Error> = .success(.stub())
    private(set) var callCount = 0
    private(set) var lastPayload: String?

    func execute(qrPayload: String) async throws -> DesktopEnrollment {
        callCount += 1
        lastPayload = qrPayload
        return try result.get()
    }
}

// MARK: - MockApproveDesktopEnrollmentUseCase

final class MockApproveDesktopEnrollmentUseCase: ApproveDesktopEnrollmentUseCaseProtocol {
    var result: Result<Void, Error> = .success(())
    private(set) var callCount = 0
    private(set) var lastTicket: DesktopEnrollmentTicket?

    func execute(ticket: DesktopEnrollmentTicket) async throws {
        callCount += 1
        lastTicket = ticket
        try result.get()
    }
}

// MARK: - Stubs

extension DesktopEnrollmentTicket {
    static func stub(
        enrollmentId: String = "550e8400-e29b-41d4-a716-446655440000",
        nonce: String = "1fd7ee6b-6f69-4fc5-873e-79ff0a10c5d6"
    ) -> DesktopEnrollmentTicket {
        DesktopEnrollmentTicket(enrollmentId: enrollmentId, nonce: nonce)
    }

    /// The compact JSON the desktop app renders into its QR.
    static func stubQRPayload(
        enrollmentId: String = "550e8400-e29b-41d4-a716-446655440000",
        nonce: String = "1fd7ee6b-6f69-4fc5-873e-79ff0a10c5d6"
    ) -> String {
        #"{"enrollmentId":"\#(enrollmentId)","nonce":"\#(nonce)"}"#
    }
}

extension DesktopEnrollmentDetails {
    static func stub(
        deviceInfo: String? = "Futmatch Desktop/1.0.0 (macOS 15.6.1; arm64)",
        appVersion: String? = "1.0.0",
        osVersion: String? = "macOS 15.6.1"
    ) -> DesktopEnrollmentDetails {
        DesktopEnrollmentDetails(deviceInfo: deviceInfo, appVersion: appVersion, osVersion: osVersion)
    }
}

extension DesktopEnrollment {
    static func stub(
        ticket: DesktopEnrollmentTicket = .stub(),
        details: DesktopEnrollmentDetails = .stub()
    ) -> DesktopEnrollment {
        DesktopEnrollment(ticket: ticket, details: details)
    }
}
