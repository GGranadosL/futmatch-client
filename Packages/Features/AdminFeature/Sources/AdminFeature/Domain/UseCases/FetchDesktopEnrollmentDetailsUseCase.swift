import Foundation

protocol FetchDesktopEnrollmentDetailsUseCaseProtocol {
    func execute(qrPayload: String) async throws -> DesktopEnrollment
}

/// Validates a scanned QR locally, then asks the backend who is behind it.
///
/// Local validation exists to keep junk scans off the network, not as a trust
/// boundary: the device details shown to the admin always come from the server.
struct FetchDesktopEnrollmentDetailsUseCase: FetchDesktopEnrollmentDetailsUseCaseProtocol {
    private let repository: DesktopEnrollmentRepositoryProtocol

    init(repository: DesktopEnrollmentRepositoryProtocol) {
        self.repository = repository
    }

    func execute(qrPayload: String) async throws -> DesktopEnrollment {
        guard let ticket = DesktopEnrollmentTicket(qrPayload: qrPayload) else {
            throw DesktopEnrollmentError.invalidQR
        }
        let details = try await repository.fetchDetails(ticket: ticket)
        return DesktopEnrollment(ticket: ticket, details: details)
    }
}
