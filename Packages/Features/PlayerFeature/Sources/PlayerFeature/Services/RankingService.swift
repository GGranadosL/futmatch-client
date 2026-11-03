import Foundation
import NetworkFramework

// MARK: - Endpoint

enum RankingEndpoint: APIEndpoint {
    case standings(RankingQuery)

    var path: String { "/rankings" }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .standings(query):
            return [
                URLQueryItem(name: "year", value: String(query.season.year)),
                URLQueryItem(name: "month", value: String(query.season.month)),
                URLQueryItem(name: "category", value: query.category.queryValue),
                URLQueryItem(name: "community", value: query.communityId),
                URLQueryItem(name: "page", value: String(query.page)),
                URLQueryItem(name: "pageSize", value: String(RankingQuery.pageSize))
            ]
        }
    }
}

// MARK: - Service

protocol RankingServiceProtocol {
    func fetchRanking(_ query: RankingQuery) async throws -> RankingBoard
}

struct RankingService: RankingServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchRanking(_ query: RankingQuery) async throws -> RankingBoard {
        let response: RankingResponse = try await apiClient.request(endpoint: RankingEndpoint.standings(query))
        return try response.data.toDomain(fallbackCategory: query.category)
    }
}
