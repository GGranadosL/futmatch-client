import Foundation
import NetworkFramework

// MARK: - Protocol

protocol MatchAdminServiceProtocol {
    func fetchAllMatches() async throws -> [AdminMatch]
    func fetchMatches(byFieldId fieldId: String) async throws -> [AdminMatch]
    func createMatch(_ params: CreateMatchParams) async throws -> AdminMatch
    func cancelMatch(matchId: String) async throws
}

// MARK: - Implementation

struct MatchAdminService: MatchAdminServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchAllMatches() async throws -> [AdminMatch] {
        let response: AdminMatchListResponseDTO = try await apiClient.request(
            endpoint: MatchAdminEndpoint.fetchAll
        )
        return response.data.map { $0.toDomain() }
    }

    func fetchMatches(byFieldId fieldId: String) async throws -> [AdminMatch] {
        let response: AdminMatchListResponseDTO = try await apiClient.request(
            endpoint: MatchAdminEndpoint.fetchByField(fieldId: fieldId)
        )
        return response.data.map { $0.toDomain() }
    }

    func createMatch(_ params: CreateMatchParams) async throws -> AdminMatch {
        let body = CreateMatchRequestDTO.from(params)
        let response: CreateMatchResponseDTO = try await apiClient.request(
            endpoint: MatchAdminEndpoint.create,
            body: body
        )
        return response.data.toDomain(fieldName: params.fieldName)
    }

    func cancelMatch(matchId: String) async throws {
        let _: CancelMatchResponseDTO = try await apiClient.request(
            endpoint: MatchAdminEndpoint.cancel(matchId: matchId)
        )
    }
}
