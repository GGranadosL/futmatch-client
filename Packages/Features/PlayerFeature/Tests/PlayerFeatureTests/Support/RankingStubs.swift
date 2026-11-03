import Foundation
@testable import PlayerFeature

extension RankingPeriod {
    static func stub(_ season: RankingSeason = RankingSeason(year: 2026, month: 11)) -> RankingPeriod {
        RankingPeriod(season: season, startTime: 0, endTimeExclusive: 1, timeZone: "UTC")
    }
}

extension HomeRanking {
    static func stub(
        season: RankingSeason = RankingSeason(year: 2026, month: 11),
        status: HomeRankingStatus = .ranked,
        position: Int? = 5,
        victories: Int = 7,
        matchesPlayed: Int = 12,
        nextTarget: RankingTarget? = RankingTarget(position: 4, victories: 8)
    ) -> HomeRanking {
        HomeRanking(
            period: .stub(season),
            community: .global,
            status: status,
            position: position,
            victories: victories,
            matchesPlayed: matchesPlayed,
            nextTarget: nextTarget,
            calculatedAt: 1_793_649_600_000
        )
    }
}

extension RankingPlayer {
    static func stub(id: String, position: Int = 1, victories: Int = 0, goals: Int = 0) -> RankingPlayer {
        RankingPlayer(
            id: id,
            name: "Player \(id)",
            avatarUrl: nil,
            gender: nil,
            country: "MX",
            position: position,
            matchesPlayed: 1,
            victories: victories,
            goals: goals
        )
    }
}

extension RankingBoard {
    static func stub(
        season: RankingSeason = RankingSeason(year: 2026, month: 11),
        category: RankingCategory = .victories,
        players: [RankingPlayer] = [.stub(id: "a")],
        currentUser: RankingPlayer? = nil,
        totalPlayers: Int? = nil,
        page: Int = 1
    ) -> RankingBoard {
        RankingBoard(
            period: .stub(season),
            community: .global,
            category: category,
            podium: Array(players.prefix(3)),
            players: players,
            currentUser: currentUser,
            totalPlayers: totalPlayers ?? players.count,
            page: page,
            pageSize: RankingQuery.pageSize,
            calculatedAt: 0
        )
    }
}

extension RankingQuery {
    static func stub(
        season: RankingSeason = RankingSeason(year: 2026, month: 11),
        category: RankingCategory = .victories,
        page: Int = 1
    ) -> RankingQuery {
        RankingQuery(season: season, communityId: "global", category: category, page: page)
    }
}
