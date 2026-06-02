import Foundation
import NetworkFramework

// MARK: - Protocol

protocol NotificationServiceProtocol {
    func fetchNotifications() async throws -> [NotificationItem]
    func deleteNotification(id: String) async throws
}

// MARK: - Implementation

final class NotificationService: NotificationServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchNotifications() async throws -> [NotificationItem] {
        let response: NotificationListResponse = try await apiClient.request(
            endpoint: NotificationEndpoint.notifications()
        )
        return response.data.map { $0.toNotificationItem() }
    }

    func deleteNotification(id: String) async throws {
        let _: DeleteNotificationResponse = try await apiClient.request(
            endpoint: NotificationEndpoint.deleteNotification(id: id)
        )
    }
}
