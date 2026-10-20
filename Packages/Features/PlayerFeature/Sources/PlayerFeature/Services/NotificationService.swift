import Foundation
import NetworkFramework

// MARK: - Protocol

protocol NotificationServiceProtocol {
    func fetchNotifications() async throws -> [NotificationItem]
    func deleteNotification(id: String) async throws
    func fetchUnreadCount() async throws -> Int
    /// Marks everything read server-side and returns how many were marked (possibly 0).
    func markAllAsRead() async throws -> Int
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

    func markAllAsRead() async throws -> Int {
        let response: MarkAllReadResponse = try await apiClient.request(
            endpoint: NotificationEndpoint.markAllRead
        )
        return response.data.markedAsReadCount
    }
}
