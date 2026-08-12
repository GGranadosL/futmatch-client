import Foundation
import NetworkFramework

// MARK: - MatchOrganizerEndpoint

enum MatchOrganizerEndpoint: APIEndpoint {
    /// `GET /match/organizer/matches`
    case fetchAll

    var path: String {
        switch self {
        case .fetchAll:
            return "/match/organizer/matches"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fetchAll:
            return .get
        }
    }
}
