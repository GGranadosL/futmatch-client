import Foundation

// MARK: - UserDefaults Notification Cache Store

/// Keeps the inbox (capped by the feed's page size) and the counter as one JSON
/// snapshot in `UserDefaults`. A single key means the list, the timestamp and the
/// counter can never disagree after a partial write.
final class UserDefaultsNotificationCacheStore: NotificationCacheStoreProtocol {

    static let storageKey = "notifications.cache.v1"
    /// Keys of the previous badge scheme (seen-ID set, count baseline, fetch timestamp),
    /// removed on `clear()` so they don't linger on upgraded devices.
    private static let legacyKeys = [
        "notifications.seenIds",
        "notifications.seenUnreadCount",
        "notification.lastFetchedAt"
    ]

    private struct Snapshot: Codable {
        var notifications: [NotificationItem] = []
        var unreadCount = 0
        var lastFetchedAt: Date?
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var notifications: [NotificationItem] { read().notifications }
    var unreadCount: Int { read().unreadCount }
    var lastFetchedAt: Date? { read().lastFetchedAt }

    func replaceNotifications(_ items: [NotificationItem], fetchedAt: Date) {
        update {
            $0.notifications = items
            $0.lastFetchedAt = fetchedAt
        }
    }

    func setUnreadCount(_ count: Int) {
        update { $0.unreadCount = max(0, count) }
    }

    func markAllRead() {
        update {
            for index in $0.notifications.indices { $0.notifications[index].isRead = true }
            $0.unreadCount = 0
        }
    }

    func removeNotification(id: String) {
        update { $0.notifications.removeAll { $0.id == id } }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: Self.storageKey)
        Self.legacyKeys.forEach(defaults.removeObject(forKey:))
    }

    // MARK: Private

    private func read() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return readLocked()
    }

    private func readLocked() -> Snapshot {
        guard let data = defaults.data(forKey: Self.storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return Snapshot()
        }
        return snapshot
    }

    private func update(_ change: (inout Snapshot) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var snapshot = readLocked()
        change(&snapshot)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
