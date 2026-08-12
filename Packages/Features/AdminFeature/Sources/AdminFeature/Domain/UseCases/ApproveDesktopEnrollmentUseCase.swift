import Foundation

protocol ApproveDesktopEnrollmentUseCaseProtocol {
    func execute(ticket: DesktopEnrollmentTicket) async throws
}

/// Authorizes the desktop installation. Only ever called after the admin taps
/// the explicit confirm action — never straight off a scan.
struct ApproveDesktopEnrollmentUseCase: ApproveDesktopEnrollmentUseCaseProtocol {
    private let repository: DesktopEnrollmentRepositoryProtocol

    init(repository: DesktopEnrollmentRepositoryProtocol) {
        self.repository = repository
    }

    func execute(ticket: DesktopEnrollmentTicket) async throws {
        try await repository.approve(ticket: ticket)
    }
}
