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
    // Demo (read-only, same auth token, dedicated backend data)
    case demoMatches(lat: Double?, lon: Double?)
    case demoMyMatches(lat: Double?, lon: Double?)
    case demoMatchDetail(id: String)

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
        case .demoMatches:
            return "/match/matches/demo"
        case .demoMyMatches:
            return "/match/my-matches/demo"
        case .demoMatchDetail(let id):
            return "/match/demo/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .matches, .matchDetail, .myMatches,
             .demoMatches, .demoMyMatches, .demoMatchDetail:
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
        case .matches(let lat, let lon),
             .myMatches(let lat, let lon),
             .demoMatches(let lat, let lon),
             .demoMyMatches(let lat, let lon):
            var items: [URLQueryItem] = []
            if let lat { items.append(URLQueryItem(name: "lat", value: "\(lat)")) }
            if let lon { items.append(URLQueryItem(name: "lon", value: "\(lon)")) }
            return items.isEmpty ? nil : items
        case .matchDetail, .joinMatch, .cancelMatch, .leaveMatch, .demoMatchDetail:
            return nil
        }
    }
}
