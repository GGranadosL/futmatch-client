import Foundation
import NetworkFramework
import SharedModels

// MARK: - Protocol

protocol HomeServiceProtocol {
    /// `rankingSeason` is the month the Ranking card asks the summary for.
    func fetchHome(rankingSeason: RankingSeason) async throws -> HomeData
}

// MARK: - Domain Model

struct HomeData {
    let greetingName: String
    let level: PlayerLevel
    let averageScore: Int
    let profileImageUrl: String?
    let suggestedMatches: [MatchItem]
    let lastMatch: LastMatch?
    /// `nil` when absent, invalid, or for a month other than the one requested.
    var ranking: HomeRanking? = nil
}

// MARK: - Implementation

final class HomeService: HomeServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchHome(rankingSeason: RankingSeason) async throws -> HomeData {
        let response: HomeResponse = try await apiClient.request(
            endpoint: HomeEndpoint.home(rankingYear: rankingSeason.year, rankingMonth: rankingSeason.month)
        )
        let dto = response.data
        return HomeData(
            greetingName: dto.profile.greetingName,
            level: dto.profile.level,
            averageScore: dto.profile.averageScore,
            profileImageUrl: dto.profile.profileImageUrl,
            suggestedMatches: dto.suggestedMatches.map { $0.toMatchItem() },
            lastMatch: dto.lastMatch?.toDomain(),
            // A summary for another month is dropped here, before it can replace the cache.
            ranking: dto.ranking?.toDomain().flatMap { $0.season == rankingSeason ? $0 : nil }
        )
    }
}
