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
    let isDemoMode: Bool

    init(apiClient: APIClient = .shared, isDemoMode: Bool = false) {
        self.apiClient = apiClient
        self.isDemoMode = isDemoMode
    }

    // MARK: - Reads

    func fetchMatches(lat: Double? = nil, lon: Double? = nil) async throws -> [MatchItem] {
        if isDemoMode {
            // Demo endpoint returns a raw JSON array — not wrapped in { "data": [...] }
            let items: [MatchListItemDTO] = try await apiClient.request(
                endpoint: MatchEndpoint.demoMatches(lat: lat, lon: lon)
            )
            return items.map { $0.toMatchItem() }
        } else {
            let response: MatchListResponse = try await apiClient.request(
                endpoint: MatchEndpoint.matches(lat: lat, lon: lon)
            )
            return response.data.map { $0.toMatchItem() }
        }
    }

    func fetchMyMatches(lat: Double? = nil, lon: Double? = nil) async throws -> [MatchItem] {
        if isDemoMode {
            // Demo endpoint returns a raw JSON array — not wrapped in { "data": [...] }
            let items: [MatchListItemDTO] = try await apiClient.request(
                endpoint: MatchEndpoint.demoMyMatches(lat: lat, lon: lon)
            )
            return items.map { $0.toMatchItem() }
        } else {
            let response: MatchListResponse = try await apiClient.request(
                endpoint: MatchEndpoint.myMatches(lat: lat, lon: lon)
            )
            return response.data.map { $0.toMatchItem() }
        }
    }

    func fetchMatchDetail(id: String) async throws -> MatchItem {
        let endpoint: MatchEndpoint = isDemoMode
            ? .demoMatchDetail(id: id)
            : .matchDetail(id: id)
        let response: MatchDetailResponse = try await apiClient.request(endpoint: endpoint)
        return response.data.toMatchItem()
    }

    // MARK: - Writes (disabled in demo)

    func joinMatch(id: String, team: String?) async throws -> JoinMatchData {
        guard !isDemoMode else { throw DemoModeError.actionNotAvailable }
        let request = JoinMatchRequest(team: team)
        let response: JoinMatchResponse = try await apiClient.request(
            endpoint: MatchEndpoint.joinMatch(id: id, request: request)
        )
        return response.data
    }

    func cancelMatch(id: String) async throws {
        guard !isDemoMode else { throw DemoModeError.actionNotAvailable }
        let _: CancelMatchResponse = try await apiClient.request(
            endpoint: MatchEndpoint.cancelMatch(id: id)
        )
    }

    func leaveMatch(id: String) async throws {
        guard !isDemoMode else { throw DemoModeError.actionNotAvailable }
        let _: LeaveMatchResponse = try await apiClient.request(
            endpoint: MatchEndpoint.leaveMatch(id: id)
        )
    }
}

// MARK: - DemoModeError

enum DemoModeError: LocalizedError {
    case actionNotAvailable

    var errorDescription: String? {
        "Esta acción no está disponible en modo demo."
    }
}
