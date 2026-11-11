import Foundation

/// No disk cache: operational counters and history are kept in memory per session
/// (same as Android) and always reconciled with the server.
struct OperationalNotificationRepository: OperationalNotificationRepositoryProtocol {
    private let service: OperationalNotificationServiceProtocol

    init(service: OperationalNotificationServiceProtocol) {
        self.service = service
    }

    func fetchNotifications(inbox: OperationalInbox) async throws -> [OperationalNotification] {
        try await service.fetchNotifications(inbox: inbox)
    }

    func fetchUnreadCount(inbox: OperationalInbox) async throws -> Int {
        try await service.fetchUnreadCount(inbox: inbox)
    }

    func markAllRead(inbox: OperationalInbox) async throws {
        try await service.markAllRead(inbox: inbox)
    }

    func delete(id: String, inbox: OperationalInbox) async throws {
        try await service.delete(id: id, inbox: inbox)
    }
}
