import Foundation
import OSLog

protocol RefreshNotificationInboxUseCaseProtocol {
    func execute() async throws -> NotificationInbox
}

/// Pull-to-refresh: marks everything read (only when something is unread), reloads the
/// history, then reconciles the counter with the server to pick up arrivals the push
/// channel missed.
struct RefreshNotificationInboxUseCase: RefreshNotificationInboxUseCaseProtocol {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FutMatch", category: "Notifications")

    private let repository: NotificationRepositoryProtocol

    init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws -> NotificationInbox {
        // A failed mark-as-read keeps the badge; the history refresh still goes ahead.
        var didMarkRead = false
        var markReadFailed = false
        if repository.cachedUnreadCount > 0 {
            do {
                try await repository.markAllAsRead()
                didMarkRead = true
            } catch {
                markReadFailed = true
                Self.logger.error("read-all failed, badge left as is: \(error.localizedDescription, privacy: .public)")
            }
        }
        try await repository.refreshNotifications()
        if !didMarkRead, !markReadFailed, repository.cachedNotifications.contains(where: { !$0.isRead }) {
            do {
                try await repository.markAllAsRead()
            } catch {
                Self.logger.error("read-all failed, badge left as is: \(error.localizedDescription, privacy: .public)")
            }
        }
        try? await repository.refreshUnreadCount()
        return NotificationInbox(items: repository.cachedNotifications, unreadCount: repository.cachedUnreadCount)
    }
}
