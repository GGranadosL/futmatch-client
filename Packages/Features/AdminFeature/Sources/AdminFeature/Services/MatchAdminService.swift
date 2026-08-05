import Foundation
import NetworkFramework

// MARK: - Protocol

protocol MatchAdminServiceProtocol {
    func fetchAllMatches() async throws -> [AdminMatch]
    func fetchMatches(byFieldId fieldId: String) async throws -> [AdminMatch]
    func createMatch(_ params: CreateMatchParams) async throws -> AdminMatch
    func updateMatch(_ params: UpdateMatchParams) async throws -> AdminMatch
    func cancelMatch(matchId: String, reason: String) async throws
    func completeMatch(params: CompleteMatchParams) async throws
    func fetchMatchDetail(matchId: String) async throws -> (teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer])
    func rebalanceTeams(matchId: String, players: [PlayerTeamAssignmentDTO]) async throws
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

    func updateMatch(_ params: UpdateMatchParams) async throws -> AdminMatch {
        let body = UpdateMatchRequestDTO.from(params)
        let response: CreateMatchResponseDTO = try await apiClient.request(
            endpoint: MatchAdminEndpoint.update(matchId: params.matchId),
            body: body
        )
        return response.data.toDomain(fieldName: params.fieldName)
    }

    func cancelMatch(matchId: String, reason: String) async throws {
        let body = CancelMatchRequestDTO(reason: reason)
        let _: CancelMatchResponseDTO = try await apiClient.request(
            endpoint: MatchAdminEndpoint.cancel(matchId: matchId),
            body: body
        )
    }

    func fetchMatchDetail(matchId: String) async throws -> (teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer]) {
        let response: AdminMatchDetailResponseDTO = try await apiClient.request(
            endpoint: MatchAdminEndpoint.fetchDetail(matchId: matchId)
        )
        return (
            teamA: response.data.teams.teamA.players.map { $0.toAdminMatchPlayer() },
            teamB: response.data.teams.teamB.players.map { $0.toAdminMatchPlayer() }
        )
    }

    func rebalanceTeams(matchId: String, players: [PlayerTeamAssignmentDTO]) async throws {
        let body = RebalanceTeamsRequestDTO(players: players)
        let _: RebalanceTeamsResponseDTO = try await apiClient.request(
            endpoint: MatchAdminEndpoint.rebalanceTeams(matchId: matchId),
            body: body
        )
    }

    func completeMatch(params: CompleteMatchParams) async throws {
        let body = CompleteMatchRequestDTO(
            goals: params.playerGoals.map {
                CompleteMatchRequestDTO.GoalDTO(userId: $0.userId, goals: $0.goals)
            },
            externalGoals: params.externalGoals.map {
                CompleteMatchRequestDTO.ExternalGoalDTO(team: $0.team, goals: $0.goals)
            },
            bestPlayerId: params.bestPlayerId,
            absentPlayerIds: params.absentPlayerIds
        )
        let _: CompleteMatchResponseDTO = try await apiClient.request(
            endpoint: MatchAdminEndpoint.complete(matchId: params.matchId),
            body: body
        )
    }
}
