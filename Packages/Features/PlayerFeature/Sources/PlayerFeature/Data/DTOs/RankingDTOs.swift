import Foundation
import SharedModels

// Ranking contracts (`/user/home` → `data.ranking`, and `/rankings`). Null and missing
// fields are both tolerated; timestamps are epoch milliseconds.

struct RankingPeriodDTO: Codable {
    let year: Int
    let month: Int
    let startTime: Int64?
    let endTimeExclusive: Int64?
    let timeZone: String?

    func toDomain() -> RankingPeriod? {
        guard (1...9999).contains(year), (1...12).contains(month) else { return nil }
        return RankingPeriod(
            season: RankingSeason(year: year, month: month),
            startTime: startTime ?? 0,
            endTimeExclusive: endTimeExclusive ?? 0,
            timeZone: timeZone ?? "UTC"
        )
    }
}

struct RankingCommunityDTO: Codable {
    let id: String?
    let name: String?

    func toDomain() -> RankingCommunity {
        let id = (id?.isEmpty == false ? id : nil) ?? RankingCommunity.globalId
        return RankingCommunity(id: id, name: name ?? id)
    }
}

struct RankingTargetDTO: Codable {
    let position: Int
    let victories: Int
}

// MARK: - Home summary

struct HomeRankingDTO: Codable {
    let period: RankingPeriodDTO?
    let community: RankingCommunityDTO?
    let category: String?
    let status: String?
    let position: Int?
    let victories: Int?
    let matchesPlayed: Int?
    let nextTarget: RankingTargetDTO?
    let calculatedAt: Int64?

    /// `nil` when the summary can't be trusted (no period, or a ranked summary
    /// without a position): the card then shows "unavailable" rather than inventing one.
    func toDomain() -> HomeRanking? {
        guard let period = period?.toDomain() else { return nil }
        let resolved: HomeRankingStatus
        switch status?.uppercased() {
        case "NOT_PARTICIPATING":
            resolved = .notParticipating
        default:
            guard position != nil else { return nil }
            resolved = .ranked
        }
        return HomeRanking(
            period: period,
            community: community?.toDomain() ?? .global,
            status: resolved,
            position: resolved == .ranked ? position : nil,
            victories: victories ?? 0,
            matchesPlayed: matchesPlayed ?? 0,
            nextTarget: resolved == .ranked ? nextTarget.map { RankingTarget(position: $0.position, victories: $0.victories) } : nil,
            calculatedAt: calculatedAt ?? 0
        )
    }
}

// MARK: - Full standings

struct RankingResponse: Decodable {
    let data: RankingResponseDTO
}

struct RankingPlayerDTO: Codable {
    let id: String
    let name: String?
    let avatarUrl: String?
    let gender: String?
    let country: String?
    let position: Int
    let matchesPlayed: Int?
    let victories: Int?
    let goals: Int?

    func toDomain() -> RankingPlayer {
        RankingPlayer(
            id: id,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            avatarUrl: avatarUrl?.isEmpty == false ? avatarUrl : nil,
            gender: gender.flatMap { Gender(rawValue: $0.uppercased()) },
            country: country,
            position: position,
            matchesPlayed: matchesPlayed ?? 0,
            victories: victories ?? 0,
            goals: goals ?? 0
        )
    }
}

struct RankingResponseDTO: Codable {
    let period: RankingPeriodDTO
    let community: RankingCommunityDTO?
    let category: String?
    let podium: [RankingPlayerDTO]?
    let players: [RankingPlayerDTO]?
    let currentUser: RankingPlayerDTO?
    let totalPlayers: Int?
    let page: Int?
    let pageSize: Int?
    let calculatedAt: Int64?

    /// `fallbackCategory` is the one that was asked for, used if the response omits it.
    func toDomain(fallbackCategory: RankingCategory) throws -> RankingBoard {
        guard let period = period.toDomain() else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid ranking period"))
        }
        let players = (players ?? []).map { $0.toDomain() }
        return RankingBoard(
            period: period,
            community: community?.toDomain() ?? .global,
            category: RankingCategory(apiValue: category) ?? fallbackCategory,
            podium: Array((podium ?? []).map { $0.toDomain() }.prefix(3)),
            players: players,
            currentUser: currentUser?.toDomain(),
            totalPlayers: totalPlayers ?? players.count,
            page: page ?? 1,
            pageSize: pageSize ?? RankingQuery.pageSize,
            calculatedAt: calculatedAt ?? 0
        )
    }
}
