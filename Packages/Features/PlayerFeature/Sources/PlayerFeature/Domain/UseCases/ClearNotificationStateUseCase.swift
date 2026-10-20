import Foundation

protocol ClearNotificationStateUseCaseProtocol {
    func execute()
}

/// Logout: the next account must not see this one's history or badge.
struct ClearNotificationStateUseCase: ClearNotificationStateUseCaseProtocol {
    private let repository: NotificationRepositoryProtocol

    init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }

    func execute() {
        repository.clearAll()
    }
}
