import Foundation
import NetworkFramework

// MARK: - Protocol

protocol NotificationServiceProtocol {
    func fetchNotifications() async throws -> [NotificationItem]
    func deleteNotification(id: String) async throws
    func fetchUnreadCount() async throws -> Int
    /// Marks everything read server-side. Any 2xx is success, including "nothing to mark".
    func markAllAsRead() async throws
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

    func fetchUnreadCount() async throws -> Int {
        let response: UnreadCountResponse = try await apiClient.request(
            endpoint: NotificationEndpoint.unreadCount
        )
        return response.data.unreadCount
    }

    func markAllAsRead() async throws {
        // The body is ignored on purpose: the caller zeroes its counter on any 2xx. A strict
        // decode of the count turned a harmless body difference into a "failed" mark-as-read
        // that was swallowed upstream, leaving the badge stuck at its last value.
        let _: EmptyResponse = try await apiClient.request(
            endpoint: NotificationEndpoint.markAllRead
        )
    }
}
