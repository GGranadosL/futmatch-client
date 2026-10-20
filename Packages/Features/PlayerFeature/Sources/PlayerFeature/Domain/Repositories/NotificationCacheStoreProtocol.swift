import Foundation

// MARK: - Notification Cache Store

/// Local copy of the notification inbox plus the unread counter behind the bell badge.
///
/// The counter lives here (not derived from the list) because it is driven by pushes
/// and by the server's own count, and has to survive relaunches until the next sync.
protocol NotificationCacheStoreProtocol {
    var notifications: [NotificationItem] { get }
    var unreadCount: Int { get }
    /// When the history was last fetched from the server. `nil` means never, which
    /// callers must treat as an expired cache.
    var lastFetchedAt: Date? { get }

    func replaceNotifications(_ items: [NotificationItem], fetchedAt: Date)
    func setUnreadCount(_ count: Int)
    /// Flags every cached notification as read and zeroes the counter.
    func markAllRead()
    func removeNotification(id: String)
    /// Drops the history, the metadata and the counter (logout).
    func clear()
}
