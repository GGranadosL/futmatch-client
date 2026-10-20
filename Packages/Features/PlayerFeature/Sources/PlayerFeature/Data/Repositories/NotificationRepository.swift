import Foundation

// MARK: - NotificationRepository

struct NotificationRepository: NotificationRepositoryProtocol {
    private let service: NotificationServiceProtocol
    private let cache: NotificationCacheStoreProtocol
    private let now: () -> Date

    init(
        service: NotificationServiceProtocol,
        cache: NotificationCacheStoreProtocol,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.cache = cache
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
        return count
    }

    func markAllAsRead() async throws {
        // A 2xx is success even when there was nothing left to mark.
        try await service.markAllAsRead()
        cache.markAllRead()
    }

    func deleteNotification(id: String) async throws {
        try await service.deleteNotification(id: id)
        cache.removeNotification(id: id)
    }

    func registerIncomingNotification() -> Int {
        let count = cache.unreadCount + 1
        cache.setUnreadCount(count)
        return count
    }

    func clearAll() {
        cache.clear()
    }
}
