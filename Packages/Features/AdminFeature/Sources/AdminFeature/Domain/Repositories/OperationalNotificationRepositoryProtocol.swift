import Foundation

public protocol OperationalNotificationRepositoryProtocol {
    func fetchNotifications(inbox: OperationalInbox) async throws -> [OperationalNotification]
    func fetchUnreadCount(inbox: OperationalInbox) async throws -> Int
    func markAllRead(inbox: OperationalInbox) async throws
    func delete(id: String, inbox: OperationalInbox) async throws
}
