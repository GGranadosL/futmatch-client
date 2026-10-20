import Foundation

protocol FetchUnreadNotificationCountUseCaseProtocol {
    func execute() async throws -> Int
}

/// Asks the server for the unread count and stores it. Called once when an
/// authenticated session starts, and again to reconcile after a pull-to-refresh.
struct FetchUnreadNotificationCountUseCase: FetchUnreadNotificationCountUseCaseProtocol {
    private let repository: NotificationRepositoryProtocol

    init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws -> Int {
        try await repository.refreshUnreadCount()
    }
}
