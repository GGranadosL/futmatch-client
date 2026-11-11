import Foundation
import OSLog

protocol OpenNotificationInboxUseCaseProtocol {
    func execute() async throws -> NotificationInbox
}

/// Runs when the notifications screen opens: marks everything read when there is
/// something to mark, and decides whether the history needs a trip to the server.
///
/// The counter is read *before* the mark-as-read call, because that call zeroes it
/// and the previous value is what says whether there is anything new to download.
/// A known zero skips the read-all request.
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

        // Known zero: no read-all. If this fails the badge and the cache stay as they
        // were, so the user can retry.
        var didMarkRead = false
        var markReadFailed = false
        if previousUnreadCount > 0 {
            do {
                try await repository.markAllAsRead()
                didMarkRead = true
            } catch {
                markReadFailed = true
                Self.logger.error("read-all failed, badge left as is: \(error.localizedDescription, privacy: .public)")
            }
        }

        let needsRefresh = previousUnreadCount >= 1
            || !hadCachedItems
            || isExpired(lastFetchedAt)
        if needsRefresh {
            try await repository.refreshNotifications()
        }

        // The counter was behind: the server has unread items we didn't know about.
        if !didMarkRead, !markReadFailed, repository.cachedNotifications.contains(where: { !$0.isRead }) {
            do {
                try await repository.markAllAsRead()
                didMarkRead = true
            } catch {
                Self.logger.error("read-all failed, badge left as is: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Pushes may have landed while marking; read-all's own count isn't the current one.
        if didMarkRead {
            try? await repository.refreshUnreadCount()
        }
        return NotificationInbox(items: repository.cachedNotifications, unreadCount: repository.cachedUnreadCount)
    }

    /// A cache that was never filled counts as expired.
    private func isExpired(_ lastFetchedAt: Date?) -> Bool {
        guard let lastFetchedAt else { return true }
        return now().timeIntervalSince(lastFetchedAt) >= cacheTimeToLive
    }
}
