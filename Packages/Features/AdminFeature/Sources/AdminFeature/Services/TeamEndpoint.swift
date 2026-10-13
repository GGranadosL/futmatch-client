import Foundation
import NetworkFramework

enum TeamEndpoint: APIEndpoint {
    /// `GET /match/admin/teams` — selectable team identities (ADMIN / ORGANIZER).
    case catalog

    var path: String {
        switch self {
        case .catalog:
            return "/match/admin/teams"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .catalog:
            return .get
        }
    }
}
