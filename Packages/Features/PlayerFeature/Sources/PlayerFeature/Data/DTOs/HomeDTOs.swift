import Foundation
import SharedModels

// MARK: - Home Response

struct HomeResponse: Decodable {
    let data: HomeDataDTO
}

struct HomeDataDTO: Codable {
    let profile: HomeProfileDTO
    let suggestedMatches: [HomeSuggestedMatchDTO]
    let lastMatch: HomeLastMatchDTO?
}

// MARK: - Profile

struct HomeProfileDTO: Codable {
    let greetingName: String
    let level: PlayerLevel
    let averageScore: Int
    let profileImageUrl: String?
}

// MARK: - Suggested Match

struct HomeSuggestedMatchDTO: Codable {
    let matchId: String
    let fieldId: String
    let fieldName: String
    let startTime: Int64
    let endTime: Int64
    let priceInCents: Int
    let imageUrl: String?

    func toMatchItem() -> MatchItem {
        let (start, end) = MatchFormatters.dates(startMs: startTime, endMs: endTime)
        return MatchItem(
            id: matchId,
            venueName: fieldName,
            timeRange: MatchFormatters.timeRange(start: start, end: end),
            date: MatchFormatters.dateString(start),
            startDate: start,
            price: MatchFormatters.priceString(priceInCents),
            matchType: "",
            spotsLeft: 0,
            fieldImageUrl: imageUrl
        )
    }
}

// MARK: - Last Match

struct HomeLastMatchDTO: Codable {
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

    private struct TeamVisualsContainer: Codable {
        let teamA: HomeTeamVisualDTO?
        let teamB: HomeTeamVisualDTO?
    }

    /// Team identities may arrive as a `teamVisuals { teamA, teamB }` snapshot (the shape
    /// every other match payload uses) or as top-level `teamA` / `teamB`; both are accepted.
    /// Matches created before team identities carry neither.
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

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(matchId, forKey: .matchId)
        try c.encode(fieldId, forKey: .fieldId)
        try c.encode(fieldName, forKey: .fieldName)
        try c.encode(playedAt, forKey: .playedAt)
        try c.encode(outcome, forKey: .outcome)
        try c.encode(teamAScore, forKey: .teamAScore)
        try c.encode(teamBScore, forKey: .teamBScore)
        try c.encodeIfPresent(teamA, forKey: .teamA)
        try c.encodeIfPresent(teamB, forKey: .teamB)
    }

    func toDomain() -> LastMatch {
        let date = Date(timeIntervalSince1970: Double(playedAt) / 1000)
        return LastMatch(
            matchId: matchId,
            fieldName: fieldName,
            playedAt: date,
            outcome: LastMatchOutcome(rawValue: outcome) ?? .draw,
            teamAScore: teamAScore,
            teamBScore: teamBScore,
            teamA: teamA?.toDomain(),
            teamB: teamB?.toDomain()
        )
    }
}

struct HomeTeamVisualDTO: Codable {
    let name: String
    let color: String?

    func toDomain() -> MatchTeamVisual {
        MatchTeamVisual(name: name, colorHex: color)
    }
}
