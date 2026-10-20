import Foundation
import OSLog

protocol OpenNotificationInboxUseCaseProtocol {
    func execute() async throws -> NotificationInbox
}

/// Runs when the notifications screen opens: marks everything read and decides
/// whether the history needs a trip to the server.
///
/// The counter is read *before* the mark-as-read call, because that call zeroes it
/// and the previous value is what says whether there is anything new to download.
struct OpenNotificationInboxUseCase: OpenNotificationInboxUseCaseProtocol {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FutMatch", category: "Notifications")

    private let repository: NotificationRepositoryProtocol
    private let now: () -> Date
    private let cacheTimeToLive: TimeInterval

    init(
        repository: NotificationRepositoryProtocol,
        cacheTimeToLive: TimeInterval = 15 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.cacheTimeToLive = cacheTimeToLive
        self.now = now
    }

    func execute() async throws -> NotificationInbox {
        let previousUnreadCount = repository.cachedUnreadCount
        let hadCachedItems = !repository.cachedNotifications.isEmpty
        let lastFetchedAt = repository.lastFetchedAt

        // If this fails the badge and the cache stay as they were, so the user can retry.
        do {
            try await repository.markAllAsRead()
        } catch {
            Self.logger.error("read-all failed, badge left as is: \(error.localizedDescription, privacy: .public)")
        }

        let needsRefresh = previousUnreadCount >= 1
            || !hadCachedItems
            || isExpired(lastFetchedAt)
        if needsRefresh {
            try await repository.refreshNotifications()
        }
        return NotificationInbox(items: repository.cachedNotifications, unreadCount: repository.cachedUnreadCount)
    }

    /// A cache that was never filled counts as expired.
    private func isExpired(_ lastFetchedAt: Date?) -> Bool {
        guard let lastFetchedAt else { return true }
        return now().timeIntervalSince(lastFetchedAt) >= cacheTimeToLive
    }
}
