import Foundation

// MARK: - Seen Notification Store

protocol SeenNotificationStoreProtocol {
    /// IDs of notifications the user has already been shown on the notifications screen.
    var seenIds: Set<String> { get }
    func markSeen(_ ids: Set<String>)
    /// Drops IDs the server no longer returns so the set can't grow without bound.
    func prune(keeping ids: Set<String>)
    func clear()
}

/// Tracks which notifications the user has already seen, keyed by ID.
///
/// The backend has no mark-as-read endpoint — `isRead` always arrives `false` — so
/// the bell badge is derived entirely from this local set. Keying by ID rather than
/// by a count means the badge survives deletions and partial refreshes: each
/// notification is judged on its own, so a delete can't silently suppress the badge
/// for a genuinely new one.
final class UserDefaultsSeenNotificationStore: SeenNotificationStoreProtocol {

    static let storageKey = "notifications.seenIds"
    /// Pre-ID badge baseline (a bare `Int`). Removed on logout so it doesn't linger
    /// on devices upgrading from the old scheme.
    static let legacyCountKey = "notifications.seenUnreadCount"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var seenIds: Set<String> {
        Set(defaults.stringArray(forKey: Self.storageKey) ?? [])
    }

    func markSeen(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        write(seenIds.union(ids))
    }

    func prune(keeping ids: Set<String>) {
        write(seenIds.intersection(ids))
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.legacyCountKey)
    }

    private func write(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: Self.storageKey)
    }
}
