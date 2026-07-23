import Foundation
import NetworkFramework

// MARK: - UserEndpoint

enum UserEndpoint: APIEndpoint {
    /// Fetches users with `ADMIN` or `ORGANIZER` role who can supervise matches.
    case organizers

    var path: String {
        switch self {
        case .organizers:
            return "/user/admin/organizers"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .organizers:
            return .get
        }
    }
}
