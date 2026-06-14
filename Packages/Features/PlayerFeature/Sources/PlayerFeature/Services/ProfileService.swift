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

    func toDomain() -> PlayerLastMatch {
        PlayerLastMatch(
            matchId: matchId,
            fieldId: fieldId,
            fieldName: fieldName,
            playedAt: Date(timeIntervalSince1970: TimeInterval(playedAt) / 1000),
            outcome: outcome,
            teamAScore: teamAScore,
            teamBScore: teamBScore
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
