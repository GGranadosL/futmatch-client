import Foundation
import NetworkFramework

// MARK: - NotificationEndpoint

enum NotificationEndpoint: APIEndpoint {
    case notifications(limit: Int = 50, offset: Int = 0)
    case deleteNotification(id: String)

    var path: String {
        switch self {
        case .notifications:
            return "/notification/"
        case .deleteNotification(let id):
            return "/notification/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .notifications:      return .get
        case .deleteNotification: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .notifications(let limit, let offset):
            return [
                URLQueryItem(name: "limit",  value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        case .deleteNotification:
            return nil
        }
    }
}
