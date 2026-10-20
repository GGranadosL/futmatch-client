import Foundation

protocol LoadCachedNotificationsUseCaseProtocol {
    func execute() -> NotificationInbox
}

struct LoadCachedNotificationsUseCase: LoadCachedNotificationsUseCaseProtocol {
    private let repository: NotificationRepositoryProtocol

    init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    func execute() -> NotificationInbox {
        NotificationInbox(items: repository.cachedNotifications, unreadCount: repository.cachedUnreadCount)
    }
}
