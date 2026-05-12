import Foundation
import NetworkFramework

// MARK: - Protocol

protocol MatchServiceProtocol {
    func fetchMatches(lat: Double?, lon: Double?) async throws -> [MatchItem]
    func fetchMyMatches(lat: Double?, lon: Double?) async throws -> [MatchItem]
    func fetchMatchDetail(id: String) async throws -> MatchItem
    func joinMatch(id: String, team: String?) async throws -> JoinMatchData
    func cancelMatch(id: String) async throws
    func leaveMatch(id: String) async throws
}

// MARK: - Implementation

final class MatchService: MatchServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }
    
    func fetchMatches(lat: Double? = nil, lon: Double? = nil) async throws -> [MatchItem] {
        let response: MatchListResponse = try await apiClient.request(
            endpoint: MatchEndpoint.matches(lat: lat, lon: lon)
        )
        return response.data.map { $0.toMatchItem() }
    }

    func fetchMyMatches(lat: Double? = nil, lon: Double? = nil) async throws -> [MatchItem] {
        let response: MatchListResponse = try await apiClient.request(
            endpoint: MatchEndpoint.myMatches(lat: lat, lon: lon)
        )
        let items = response.data.map { $0.toMatchItem() }
        return items
    }

    func fetchMatchDetail(id: String) async throws -> MatchItem {
        let response: MatchDetailResponse = try await apiClient.request(
            endpoint: MatchEndpoint.matchDetail(id: id)
        )
        return response.data.toMatchItem()
    }
    
    func joinMatch(id: String, team: String?) async throws -> JoinMatchData {
        let request = JoinMatchRequest(team: team)
        let response: JoinMatchResponse = try await apiClient.request(
            endpoint: MatchEndpoint.joinMatch(id: id, request: request)
        )
        return response.data
    }

    func cancelMatch(id: String) async throws {
        let _: CancelMatchResponse = try await apiClient.request(
            endpoint: MatchEndpoint.cancelMatch(id: id)
        )
    }

    func leaveMatch(id: String) async throws {
        let _: LeaveMatchResponse = try await apiClient.request(
            endpoint: MatchEndpoint.leaveMatch(id: id)
        )
    }
}
