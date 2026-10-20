import Foundation

// MARK: - Notification Repository

protocol NotificationRepositoryProtocol {
    var cachedNotifications: [NotificationItem] { get }
    var cachedUnreadCount: Int { get }
    var lastFetchedAt: Date? { get }

    /// Fetches the history and replaces the local copy. The counter is left alone.
    @discardableResult
    func refreshNotifications() async throws -> [NotificationItem]
    /// Fetches the server's unread count and stores it.
    @discardableResult
    func refreshUnreadCount() async throws -> Int
    /// Marks everything read on the server. Only after it succeeds are the cached
    /// items flagged and the counter zeroed; on failure nothing local changes.
    func markAllAsRead() async throws
    /// Deletes on the server, then removes the item from the local copy.
    func deleteNotification(id: String) async throws
    /// Adds one to the local counter without a request (a user push just arrived).
    @discardableResult
    func registerIncomingNotification() -> Int
    func clearAll()
}
