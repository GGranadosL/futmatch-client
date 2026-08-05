import Foundation

// MARK: - Notification Fetch Timestamp Store

protocol NotificationFetchTimestampStoreProtocol {
    /// When the notifications feed was last fetched from the network, if ever.
    var lastFetchedAt: Date? { get }
    func setLastFetchedAt(_ date: Date)
    func clear()
}

/// Lightweight `UserDefaults`-backed safety-net timestamp.
///
/// The primary refresh trigger for notifications is a push arriving
/// (`InAppNotificationPushRouter`); this timestamp only guards against the case
/// where a push is missed (FCM delivery isn't guaranteed), so an automatic call
/// site (foreground, screen open) still forces a real fetch once it's stale.
final class UserDefaultsNotificationFetchTimestampStore: NotificationFetchTimestampStoreProtocol {

    static let storageKey = "notification.lastFetchedAt"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastFetchedAt: Date? {
        (defaults.object(forKey: Self.storageKey) as? Double).map(Date.init(timeIntervalSince1970:))
    }

    func setLastFetchedAt(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: Self.storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
