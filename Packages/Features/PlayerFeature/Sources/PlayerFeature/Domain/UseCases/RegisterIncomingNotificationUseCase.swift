import Foundation

protocol RegisterIncomingNotificationUseCaseProtocol {
    /// Returns the new unread count.
    func execute() -> Int
}

/// A visible push for a user notification arrived: bump the local counter, no request.
/// Technical pushes (`matches_updated`) never reach this.
struct RegisterIncomingNotificationUseCase: RegisterIncomingNotificationUseCaseProtocol {
    private let repository: NotificationRepositoryProtocol

    init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    func execute() -> Int {
        repository.registerIncomingNotification()
    }
}
