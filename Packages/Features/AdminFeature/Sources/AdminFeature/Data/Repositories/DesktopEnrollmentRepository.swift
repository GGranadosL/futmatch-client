import Foundation

struct DesktopEnrollmentRepository: DesktopEnrollmentRepositoryProtocol {
    private let service: DesktopDeviceServiceProtocol

    init(service: DesktopDeviceServiceProtocol) {
        self.service = service
    }

    func fetchDetails(ticket: DesktopEnrollmentTicket) async throws -> DesktopEnrollmentDetails {
        try await service.fetchEnrollmentDetails(DesktopEnrollmentRequestDTO(ticket: ticket))
    }

    func approve(ticket: DesktopEnrollmentTicket) async throws {
        try await service.approveEnrollment(DesktopEnrollmentRequestDTO(ticket: ticket))
    }
}
