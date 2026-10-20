import Foundation

protocol RefreshNotificationInboxUseCaseProtocol {
    func execute() async throws -> NotificationInbox
}

/// Pull-to-refresh: marks everything read, reloads the history, then reconciles the
/// counter with the server to pick up arrivals the push channel missed.
struct RefreshNotificationInboxUseCase: RefreshNotificationInboxUseCaseProtocol {
    private let repository: NotificationRepositoryProtocol

    init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws -> NotificationInbox {
        // A failed mark-as-read keeps the badge; the history refresh still goes ahead.
        try? await repository.markAllAsRead()
        try await repository.refreshNotifications()
        try? await repository.refreshUnreadCount()
        return NotificationInbox(items: repository.cachedNotifications, unreadCount: repository.cachedUnreadCount)
    }
}
