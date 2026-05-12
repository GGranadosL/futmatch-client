import Foundation
import NetworkFramework

// MARK: - Protocol

protocol HomeServiceProtocol {
    func fetchHome() async throws -> HomeData
}

// MARK: - Domain Model

struct HomeData {
    let greetingName: String
    let level: String
    let averageScore: Int
    let profileImageUrl: String?
    let suggestedMatches: [MatchItem]
    let lastMatch: LastMatch?
}

// MARK: - Implementation

final class HomeService: HomeServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchHome() async throws -> HomeData {
        let response: HomeResponse = try await apiClient.request(endpoint: HomeEndpoint.home)
        let dto = response.data
        return HomeData(
            greetingName: dto.profile.greetingName,
            level: dto.profile.level,
            averageScore: dto.profile.averageScore,
            profileImageUrl: dto.profile.profileImageUrl,
            suggestedMatches: dto.suggestedMatches.map { $0.toMatchItem() },
            lastMatch: dto.lastMatch?.toDomain()
        )
    }
}
