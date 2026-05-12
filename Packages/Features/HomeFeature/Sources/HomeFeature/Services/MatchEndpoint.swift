import Foundation
import NetworkFramework

// MARK: - MatchEndpoint

enum MatchEndpoint: APIEndpoint {
    case matches(lat: Double?, lon: Double?)
    case myMatches(lat: Double?, lon: Double?)
    case matchDetail(id: String)
    case joinMatch(id: String, request: JoinMatchRequest)
    case cancelMatch(id: String)
    case leaveMatch(id: String)

    var path: String {
        switch self {
        case .matches:
            return "/match/matches"
        case .myMatches:
            return "/match/my-matches"
        case .matchDetail(let id):
            return "/match/\(id)"
        case .joinMatch(let id, _):
            return "/match/\(id)/join"
        case .cancelMatch(let id):
            return "/match/admin/cancel/\(id)"
        case .leaveMatch(let id):
            return "/match/\(id)/leave"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .matches, .matchDetail, .myMatches:
            return .get
        case .joinMatch, .leaveMatch:
            return .post
        case .cancelMatch:
            return .patch
        }
    }

    var body: Data? {
        switch self {
        case .joinMatch(_, let request):
            return try? JSONEncoder().encode(request)
        default:
            return nil
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .matches(let lat, let lon), .myMatches(let lat, let lon):
            var items: [URLQueryItem] = []
            if let lat { items.append(URLQueryItem(name: "lat", value: "\(lat)")) }
            if let lon { items.append(URLQueryItem(name: "lon", value: "\(lon)")) }
            return items.isEmpty ? nil : items
        case .matchDetail, .joinMatch, .cancelMatch, .leaveMatch:
            return nil
        }
    }
}
