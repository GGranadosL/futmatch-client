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

    func toDomain() -> LastMatch {
        let date = Date(timeIntervalSince1970: Double(playedAt) / 1000)
        return LastMatch(
            matchId: matchId,
            fieldName: fieldName,
            playedAt: date,
            outcome: LastMatchOutcome(rawValue: outcome) ?? .draw,
            teamAScore: teamAScore,
            teamBScore: teamBScore
        )
    }
}
