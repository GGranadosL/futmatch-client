import Foundation
import NetworkFramework

// MARK: - Protocol

protocol UserServiceProtocol {
    func fetchOrganizers() async throws -> [Organizer]
}

// MARK: - Implementation

struct UserService: UserServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchOrganizers() async throws -> [Organizer] {
        let response: OrganizersResponseDTO = try await apiClient.request(endpoint: UserEndpoint.organizers)
        return response.data.map { $0.toDomain() }
    }
}
