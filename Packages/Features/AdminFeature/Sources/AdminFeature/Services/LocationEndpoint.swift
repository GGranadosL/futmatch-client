import Foundation
import NetworkFramework

// MARK: - LocationEndpoint

enum LocationEndpoint: APIEndpoint {
    case create
    case list
    case get(id: String)
    case update
    case delete(id: String)

    var path: String {
        switch self {
        case .create:
            return "/locations"
        case .list:
            return "/locations"
        case let .get(id):
            return "/locations/\(id)"
        case .update:
            return "/locations"
        case let .delete(id):
            return "/locations/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create:
            return .post
        case .list:
            return .get
        case .get:
            return .get
        case .update:
            return .put
        case .delete:
            return .delete
        }
    }
}
