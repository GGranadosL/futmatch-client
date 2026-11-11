import Foundation
import NetworkFramework

// MARK: - AdminUsersEndpoint

/// `/admin/users` endpoints. All of them require the ADMIN role on the server.
enum AdminUsersEndpoint: APIEndpoint {
    case list(roles: [AdminUserRole], page: Int, pageSize: Int)
    case detail(userId: String)
    case paymentHistory(userId: String, page: Int)
    case updateAccess(userId: String)

    var path: String {
        switch self {
        case .list:
            return "/admin/users"
        case let .detail(userId):
            return "/admin/users/\(userId)"
        case let .paymentHistory(userId, _):
            return "/admin/users/\(userId)/payment-history"
        case let .updateAccess(userId):
            return "/admin/users/\(userId)/access"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail, .paymentHistory: return .get
        case .updateAccess: return .patch
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .list(roles, page, pageSize):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "pageSize", value: String(pageSize))
            ]
            let raw = roles.filter { $0 != .unknown }.map(\.rawValue)
            if !raw.isEmpty {
                items.insert(URLQueryItem(name: "roles", value: raw.joined(separator: ",")), at: 0)
            }
            return items
        case let .paymentHistory(_, page):
            return [URLQueryItem(name: "page", value: String(page))]
        case .detail, .updateAccess:
            return nil
        }
    }
}
