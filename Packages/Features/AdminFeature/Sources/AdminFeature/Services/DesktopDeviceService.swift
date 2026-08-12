import Foundation
import NetworkFramework

// MARK: - DesktopDeviceServiceProtocol

protocol DesktopDeviceServiceProtocol {
    func fetchEnrollmentDetails(_ request: DesktopEnrollmentRequestDTO) async throws -> DesktopEnrollmentDetails
    func approveEnrollment(_ request: DesktopEnrollmentRequestDTO) async throws
}

// MARK: - DesktopDeviceService

struct DesktopDeviceService: DesktopDeviceServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchEnrollmentDetails(_ request: DesktopEnrollmentRequestDTO) async throws -> DesktopEnrollmentDetails {
        let response: DesktopEnrollmentDetailsResponseDTO = try await apiClient.request(
            endpoint: DesktopDeviceEndpoint.enrollmentDetails,
            body: request
        )
        return response.data.toDomain()
    }

    /// Returns `201 Created` with an envelope the client ignores, so decode into
    /// `EmptyResponse` — a 2xx alone counts as success.
    func approveEnrollment(_ request: DesktopEnrollmentRequestDTO) async throws {
        let _: EmptyResponse = try await apiClient.request(
            endpoint: DesktopDeviceEndpoint.approveEnrollment,
            body: request
        )
    }
}
