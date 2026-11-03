import Foundation
import NetworkFramework

enum HomeEndpoint: APIEndpoint {
    /// `rankingYear`/`rankingMonth` are always sent together: the device's current month
    /// for the Ranking card's summary.
    case home(rankingYear: Int, rankingMonth: Int)

    var path: String {
        "/user/home"
    }

    var method: HTTPMethod {
        .get
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .home(year, month):
            return [
                URLQueryItem(name: "rankingYear", value: String(year)),
                URLQueryItem(name: "rankingMonth", value: String(month))
            ]
        }
    }
}
