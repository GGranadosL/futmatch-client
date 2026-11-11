import Foundation
import NetworkFramework

// MARK: - Endpoint

/// `/notification` endpoints scoped to an operational inbox (`?inbox=ADMIN|ORGANIZER`).
enum OperationalNotificationEndpoint: APIEndpoint {
    case list(inbox: OperationalInbox, limit: Int, offset: Int)
    case unreadCount(inbox: OperationalInbox)
    case markAllRead(inbox: OperationalInbox)
    case delete(id: String, inbox: OperationalInbox)

    var path: String {
        switch self {
        case .list: return "/notification/"
        case .unreadCount: return "/notification/unread-count"
        case .markAllRead: return "/notification/read-all"
        case let .delete(id, _): return "/notification/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .unreadCount: return .get
        case .markAllRead: return .patch
        case .delete: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .list(inbox, limit, offset):
            return [
                URLQueryItem(name: "inbox", value: inbox.rawValue),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        case let .unreadCount(inbox), let .markAllRead(inbox), let .delete(_, inbox):
            return [URLQueryItem(name: "inbox", value: inbox.rawValue)]
        }
    }
}

// MARK: - DTOs

struct OperationalNotificationListResponseDTO: Decodable {
    let data: [OperationalNotificationDTO]
}

struct OperationalNotificationDTO: Decodable {
    let id: String
    let title: String?
    let body: String?
    let notificationType: String?
    let createdAt: Int64?
    let metadata: String?
    let isRead: Bool?

    private struct Metadata: Decodable { let matchId: String? }

    func toDomain() -> OperationalNotification {
        let matchId = metadata
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(Metadata.self, from: $0) }?
            .matchId
        return OperationalNotification(
            id: id,
            title: title ?? "",
            body: body ?? "",
            type: notificationType ?? "",
            createdAt: Date(epochMillis: createdAt) ?? Date(timeIntervalSince1970: 0),
            isRead: isRead ?? true,
            matchId: matchId.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}

struct OperationalUnreadCountResponseDTO: Decodable {
    struct DataDTO: Decodable { let unreadCount: Int }
    let data: DataDTO
}

// MARK: - Service

protocol OperationalNotificationServiceProtocol {
    func fetchNotifications(inbox: OperationalInbox) async throws -> [OperationalNotification]
    func fetchUnreadCount(inbox: OperationalInbox) async throws -> Int
    func markAllRead(inbox: OperationalInbox) async throws
    func delete(id: String, inbox: OperationalInbox) async throws
}

struct OperationalNotificationService: OperationalNotificationServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchNotifications(inbox: OperationalInbox) async throws -> [OperationalNotification] {
        let response: OperationalNotificationListResponseDTO = try await apiClient.request(
            endpoint: OperationalNotificationEndpoint.list(inbox: inbox, limit: 50, offset: 0)
        )
        return response.data.map { $0.toDomain() }
    }

    func fetchUnreadCount(inbox: OperationalInbox) async throws -> Int {
        let response: OperationalUnreadCountResponseDTO = try await apiClient.request(
            endpoint: OperationalNotificationEndpoint.unreadCount(inbox: inbox)
        )
        return response.data.unreadCount
    }

    func markAllRead(inbox: OperationalInbox) async throws {
        // `markedAsReadCount` isn't the current count, so the body is ignored; callers
        // re-fetch the count afterwards.
        let _: EmptyResponse = try await apiClient.request(
            endpoint: OperationalNotificationEndpoint.markAllRead(inbox: inbox)
        )
    }

    func delete(id: String, inbox: OperationalInbox) async throws {
        let _: EmptyResponse = try await apiClient.request(
            endpoint: OperationalNotificationEndpoint.delete(id: id, inbox: inbox)
        )
    }
}
