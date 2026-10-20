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

    var queryItems: [URLQueryItem]? {
        switch self {
        case .notifications(let limit, let offset):
            return [
                URLQueryItem(name: "limit",  value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        case .deleteNotification, .unreadCount, .markAllRead:
            return nil
        }
    }
}
