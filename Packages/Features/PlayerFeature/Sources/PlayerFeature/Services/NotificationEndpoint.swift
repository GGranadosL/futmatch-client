import Foundation
import NetworkFramework

// MARK: - NotificationEndpoint

enum NotificationEndpoint: APIEndpoint {
    case notifications(limit: Int = 50, offset: Int = 0)
    case deleteNotification(id: String)
    case unreadCount
    case markAllRead

    var path: String {
        switch self {
        case .notifications:
            return "/notification/"
        case .deleteNotification(let id):
            return "/notification/\(id)"
        case .unreadCount:
            return "/notification/unread-count"
        case .markAllRead:
            return "/notification/read-all"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .notifications:      return .get
        case .deleteNotification: return .delete
        case .unreadCount:        return .get
        case .markAllRead:        return .patch
        }
    }

    /// The player inbox, sent explicitly (the backend also defaults to it). ADMIN and
    /// ORGANIZER inboxes live in AdminFeature.
    static let playerInbox = URLQueryItem(name: "inbox", value: "PLAYER")

    var queryItems: [URLQueryItem]? {
        switch self {
        case .notifications(let limit, let offset):
            return [
                Self.playerInbox,
                URLQueryItem(name: "limit",  value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        case .deleteNotification, .unreadCount, .markAllRead:
            return [Self.playerInbox]
        }
    }
}
