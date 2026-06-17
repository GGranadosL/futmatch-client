import Foundation
import NetworkFramework

// MARK: - MatchAdminEndpoint

enum MatchAdminEndpoint: APIEndpoint {
    /// `GET /match/admin/matches`
    case fetchAll
    /// `GET /match/admin/matches/{fieldId}`
    case fetchByField(fieldId: String)
    /// `POST /match/admin/create`
    case create
    /// `PUT /match/admin/update/{matchId}`
    case update(matchId: String)
    /// `PATCH /match/admin/cancel/{matchId}`
    case cancel(matchId: String)
    /// `POST /match/admin/{matchId}/complete`
    case complete(matchId: String)

    var path: String {
        switch self {
        case .fetchAll:
            return "/match/admin/matches"
        case let .fetchByField(fieldId):
            return "/match/admin/matches/\(fieldId)"
        case .create:
            return "/match/admin/create"
        case let .update(matchId):
            return "/match/admin/update/\(matchId)"
        case let .cancel(matchId):
            return "/match/admin/cancel/\(matchId)"
        case let .complete(matchId):
            return "/match/admin/\(matchId)/complete"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fetchAll, .fetchByField:
            return .get
        case .create, .complete:
            return .post
        case .update:
            return .put
        case .cancel:
            return .patch
        }
    }
}
