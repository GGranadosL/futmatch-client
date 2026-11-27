import Foundation

// MARK: - NotificationRepository

struct NotificationRepository: NotificationRepositoryProtocol {
    private let service: NotificationServiceProtocol
    private let cache: NotificationCacheStoreProtocol
    private let badge: AppIconBadgeProtocol
    private let now: () -> Date

    init(
        service: NotificationServiceProtocol,
        cache: NotificationCacheStoreProtocol,
        badge: AppIconBadgeProtocol,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.cache = cache
        self.badge = badge
        self.now = now
    }

    var cachedNotifications: [NotificationItem] { cache.notifications }
    var cachedUnreadCount: Int { cache.unreadCount }
    var lastFetchedAt: Date? { cache.lastFetchedAt }

    func refreshNotifications() async throws -> [NotificationItem] {
        let items = try await service.fetchNotifications()
        cache.replaceNotifications(items, fetchedAt: now())
        return items
    }

    func refreshUnreadCount() async throws -> Int {
        let count = try await service.fetchUnreadCount()
        cache.setUnreadCount(count)
        syncAppIconBadge()
        return count
    }

    func markAllAsRead() async throws {
        // A 2xx is success even when there was nothing left to mark.
        try await service.markAllAsRead()
        cache.markAllRead()
        syncAppIconBadge()
    }

    func deleteNotification(id: String) async throws {
        try await service.deleteNotification(id: id)
        cache.removeNotification(id: id)
    }

    func registerIncomingNotification() -> Int {
        let count = cache.unreadCount + 1
        cache.setUnreadCount(count)
        syncAppIconBadge()
        return count
    }

    func clearAll() {
        cache.clear()
        badge.setCount(0)
    }

    /// The app icon shows the same number as the bell. Every change to the counter
    /// above ends here, so the two can't drift apart.
    func syncAppIconBadge() {
        badge.setCount(cache.unreadCount)
    }
}
