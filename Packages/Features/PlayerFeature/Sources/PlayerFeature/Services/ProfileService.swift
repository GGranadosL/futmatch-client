import Foundation
import NetworkFramework
import SharedModels

// MARK: - Protocol

protocol ProfileServiceProtocol {
    func fetchPublicProfile(userId: String) async throws -> PublicPlayerProfile
}

// MARK: - DTOs

private struct PublicProfileResponse: Decodable {
    let data: PublicProfileDTO
}

private struct PublicProfileDTO: Decodable {
    let id: String
    let name: String
    let lastName: String
    let country: String
    /// Raw gender string ("MALE"/"FEMALE"/"OTHER"); tolerated as nil when the
    /// backend omits it or sends an unknown value.
    let gender: String?
    let playerPosition: PlayerPosition
    let profilePic: String?
    let level: PlayerLevel
    let averageScore: Int
    let stats: PublicStatsDTO
    let lastMatch: PublicLastMatchDTO?

    func toDomain() -> PublicPlayerProfile {
        PublicPlayerProfile(
            id: id,
            name: name,
            lastName: lastName,
            country: country,
            gender: gender.flatMap(Gender.init(rawValue:)),
            playerPosition: playerPosition,
            profilePic: profilePic,
            level: level,
            averageScore: averageScore,
            stats: stats.toDomain(),
            lastMatch: lastMatch?.toDomain()
        )
    }
}

private struct PublicStatsDTO: Decodable {
    let matchesPlayed: Int
    let matchesWon: Int
    let mvpCount: Int
    let totalGoals: Int

    func toDomain() -> PlayerStats {
        PlayerStats(
            matchesPlayed: matchesPlayed,
            matchesWon: matchesWon,
            mvpCount: mvpCount,
            totalGoals: totalGoals
        )
    }
}

private struct PublicLastMatchDTO: Decodable {
    let matchId: String
    let fieldId: String
    let fieldName: String
    let playedAt: Int64
    let outcome: String
    let teamAScore: Int
    let teamBScore: Int
    let teamA: HomeTeamVisualDTO?
    let teamB: HomeTeamVisualDTO?

    private enum CodingKeys: String, CodingKey {
        case matchId, fieldId, fieldName, playedAt, outcome, teamAScore, teamBScore, teamA, teamB, teamVisuals
    }

    private struct TeamVisualsContainer: Decodable {
        let teamA: HomeTeamVisualDTO?
        let teamB: HomeTeamVisualDTO?
    }

    /// Same tolerance as `HomeLastMatchDTO`: teams may come top-level or inside
    /// `teamVisuals`, and older matches carry neither.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matchId = try c.decode(String.self, forKey: .matchId)
        fieldId = try c.decode(String.self, forKey: .fieldId)
        fieldName = try c.decode(String.self, forKey: .fieldName)
        playedAt = try c.decode(Int64.self, forKey: .playedAt)
        outcome = try c.decode(String.self, forKey: .outcome)
        teamAScore = try c.decode(Int.self, forKey: .teamAScore)
        teamBScore = try c.decode(Int.self, forKey: .teamBScore)
        let nested = try c.decodeIfPresent(TeamVisualsContainer.self, forKey: .teamVisuals)
        teamA = try c.decodeIfPresent(HomeTeamVisualDTO.self, forKey: .teamA) ?? nested?.teamA
        teamB = try c.decodeIfPresent(HomeTeamVisualDTO.self, forKey: .teamB) ?? nested?.teamB
    }

    func toDomain() -> PlayerLastMatch {
        PlayerLastMatch(
            matchId: matchId,
            fieldId: fieldId,
            fieldName: fieldName,
            playedAt: Date(timeIntervalSince1970: TimeInterval(playedAt) / 1000),
            outcome: outcome,
            teamAScore: teamAScore,
            teamBScore: teamBScore,
            teamA: teamA.map { PlayerLastMatchTeam(name: $0.name, colorHex: $0.color) },
            teamB: teamB.map { PlayerLastMatchTeam(name: $0.name, colorHex: $0.color) }
        )
    }
}

// MARK: - Implementation

struct ProfileService: ProfileServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchPublicProfile(userId: String) async throws -> PublicPlayerProfile {
        let response: PublicProfileResponse = try await apiClient.request(
            endpoint: ProfileEndpoint.publicProfile(userId: userId)
        )
        return response.data.toDomain()
    }
}
