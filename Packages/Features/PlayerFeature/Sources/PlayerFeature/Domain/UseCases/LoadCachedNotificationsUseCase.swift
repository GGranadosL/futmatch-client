import Foundation

protocol LoadCachedNotificationsUseCaseProtocol {
    func execute() -> NotificationInbox
}

struct LoadCachedNotificationsUseCase: LoadCachedNotificationsUseCaseProtocol {
    private let repository: NotificationRepositoryProtocol

    init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    /// Also puts the cached counter on the app icon, so it is right from launch,
    /// before the session's unread count comes back from the server.
    func execute() -> NotificationInbox {
        repository.syncAppIconBadge()
        return NotificationInbox(items: repository.cachedNotifications, unreadCount: repository.cachedUnreadCount)
    }
}
