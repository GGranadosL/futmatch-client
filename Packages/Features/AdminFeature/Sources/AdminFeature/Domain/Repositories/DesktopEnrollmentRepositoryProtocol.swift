import Foundation

protocol DesktopEnrollmentRepositoryProtocol {
    /// Server-backed details for a pending enrollment. Throws when the QR is
    /// unknown, expired, or already consumed.
    func fetchDetails(ticket: DesktopEnrollmentTicket) async throws -> DesktopEnrollmentDetails

    /// Consumes the enrollment and registers the desktop device under the
    /// approving admin. A second approval with the same ticket fails.
    func approve(ticket: DesktopEnrollmentTicket) async throws
}
