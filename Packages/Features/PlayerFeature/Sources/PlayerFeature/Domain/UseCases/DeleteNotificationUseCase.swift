import Foundation

protocol DeleteNotificationUseCaseProtocol {
    func execute(id: String) async throws
}

struct DeleteNotificationUseCase: DeleteNotificationUseCaseProtocol {
    private let repository: NotificationRepositoryProtocol

    init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(id: String) async throws {
        try await repository.deleteNotification(id: id)
    }
}
