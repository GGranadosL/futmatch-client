import Foundation
import NetworkFramework

// MARK: - Protocol

protocol NotificationPreferencesServiceProtocol {
    func fetchMatchInvitesEnabled() async throws -> Bool
    func updateMatchInvitesEnabled(_ enabled: Bool) async throws
}

// MARK: - Implementation

struct NotificationPreferencesService: NotificationPreferencesServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchMatchInvitesEnabled() async throws -> Bool {
        let response: NotificationPreferencesResponse = try await apiClient.request(
            endpoint: NotificationPreferencesEndpoint.current
        )
        // The backend turns invites on by default; a server that doesn't send the
        // field yet means the same.
        return response.data.matchInviteNotificationsEnabled ?? true
    }

    func updateMatchInvitesEnabled(_ enabled: Bool) async throws {
        let _: EmptyResponse = try await apiClient.request(
            endpoint: NotificationPreferencesEndpoint.update,
            body: UpdateNotificationPreferencesRequest(matchInvitesEnabled: enabled)
        )
    }
}

// MARK: - DTOs

/// Only the preference fields of `GET /user`; the rest of the user is read elsewhere.
struct NotificationPreferencesResponse: Decodable {
    struct Payload: Decodable {
        let matchInviteNotificationsEnabled: Bool?
    }
    let data: Payload
}

struct UpdateNotificationPreferencesRequest: Encodable {
    let matchInvitesEnabled: Bool
}
