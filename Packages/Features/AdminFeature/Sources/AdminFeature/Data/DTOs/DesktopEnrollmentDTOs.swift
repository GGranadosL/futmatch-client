import Foundation

// MARK: - Request

/// Body shared by both desktop-enrollment endpoints.
struct DesktopEnrollmentRequestDTO: Encodable {
    let enrollmentId: String
    let nonce: String

    init(ticket: DesktopEnrollmentTicket) {
        self.enrollmentId = ticket.enrollmentId
        self.nonce = ticket.nonce
    }
}

// MARK: - Response

struct DesktopEnrollmentDetailsResponseDTO: Decodable {
    let data: DesktopEnrollmentDetailsDTO
}

/// All three fields are nullable by contract — older desktop builds create
/// enrollments without them.
struct DesktopEnrollmentDetailsDTO: Decodable {
    let deviceInfo: String?
    let appVersion: String?
    let osVersion: String?

    func toDomain() -> DesktopEnrollmentDetails {
        DesktopEnrollmentDetails(
            deviceInfo: deviceInfo,
            appVersion: appVersion,
            osVersion: osVersion
        )
    }
}
