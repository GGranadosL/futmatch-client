import Foundation
import SharedModels

// MARK: - Season

/// A ranking month. Only an identity for the selector and the query: the server decides
/// which matches fall in it (UTC boundaries), the device only picks which month to ask for.
struct RankingSeason: Hashable, Codable {
    let year: Int
    let month: Int

    /// The month on the device's calendar and time zone, year and month read together.
    static func current(now: Date = Date(), calendar: Calendar = .current) -> RankingSeason {
        let parts = calendar.dateComponents([.year, .month], from: now)
        return RankingSeason(year: parts.year ?? 1970, month: parts.month ?? 1)
    }

    /// `offset` months before this one, crossing into the previous year when needed.
    func monthsBefore(_ offset: Int) -> RankingSeason {
        let index = year * 12 + (month - 1) - offset
        return RankingSeason(year: index / 12, month: index % 12 + 1)
    }

    /// The selector's options: this month plus the three before it, newest first.
    var selectableSeasons: [RankingSeason] {
        (0...3).map { monthsBefore($0) }
    }
}

// MARK: - Category

enum RankingCategory: String, CaseIterable, Codable {
    case victories
    case goals

    /// Lowercase value the `/rankings` query expects.
    var queryValue: String { rawValue }

    /// The response spells it in uppercase (`VICTORIES` / `GOALS`).
    init?(apiValue: String?) {
        guard let apiValue else { return nil }
        self.init(rawValue: apiValue.lowercased())
    }
}

// MARK: - Shared pieces

struct RankingCommunity: Equatable, Codable {
    static let globalId = "global"

    let id: String
    let name: String

    var isGlobal: Bool { id == Self.globalId }

    static let global = RankingCommunity(id: globalId, name: "Global")
}

struct RankingPeriod: Equatable, Codable {
    let season: RankingSeason
    /// Epoch milliseconds, inclusive.
    let startTime: Int64
    /// Epoch milliseconds, exclusive.
    let endTimeExclusive: Int64
    /// The zone the server cuts the month in (UTC today).
    let timeZone: String
}

struct RankingTarget: Equatable, Codable {
    let position: Int
    let victories: Int
}

// MARK: - Home summary

enum HomeRankingStatus: String, Codable {
    case ranked
    case notParticipating
}

/// The Victories summary that `/user/home` carries for the Ranking card.
struct HomeRanking: Equatable, Codable {
    let period: RankingPeriod
    let community: RankingCommunity
    let status: HomeRankingStatus
    let position: Int?
    let victories: Int
    let matchesPlayed: Int
    let nextTarget: RankingTarget?
    /// Epoch milliseconds.
    let calculatedAt: Int64

    var season: RankingSeason { period.season }
    var isParticipating: Bool { status == .ranked }

    /// Wins needed to tie the next score above. `nil` when there is nothing above
    /// (shared first place) or the gap isn't positive — never an invented goal.
    var victoriesToTarget: Int? {
        guard isParticipating, let nextTarget else { return nil }
        let difference = nextTarget.victories - victories
        return difference > 0 ? difference : nil
    }
}

// MARK: - Full standings

struct RankingPlayer: Equatable, Identifiable, Codable {
    let id: String
    let name: String
    let avatarUrl: String?
    let gender: Gender?
    /// ISO-2 code, as in Match Detail.
    let country: String?
    let position: Int
    let matchesPlayed: Int
    let victories: Int
    let goals: Int

    func score(for category: RankingCategory) -> Int {
        switch category {
        case .victories: return victories
        case .goals: return goals
        }
    }
}

struct RankingBoard: Equatable, Codable {
    let period: RankingPeriod
    let community: RankingCommunity
    let category: RankingCategory
    /// Up to three players, independent of the page.
    let podium: [RankingPlayer]
    let players: [RankingPlayer]
    /// The signed-in player, even when outside `players`; `nil` without eligible participation.
    let currentUser: RankingPlayer?
    let totalPlayers: Int
    let page: Int
    let pageSize: Int
    /// Epoch milliseconds.
    let calculatedAt: Int64

    var hasMore: Bool {
        Int64(page) * Int64(pageSize) < Int64(totalPlayers)
    }

    /// Whether `currentUser` sits in the rows already loaded (matched by id, never by name).
    var currentUserIsListed: Bool {
        guard let currentUser else { return false }
        return players.contains { $0.id == currentUser.id }
    }

    /// This board with `next`'s rows added after the current ones, skipping ids already
    /// shown. Metadata (page, totals, current user) comes from the newer page.
    func appending(_ next: RankingBoard) -> RankingBoard {
        let known = Set(players.map(\.id))
        return RankingBoard(
            period: next.period,
            community: next.community,
            category: next.category,
            podium: next.podium,
            players: players + next.players.filter { !known.contains($0.id) },
            currentUser: next.currentUser,
            totalPlayers: next.totalPlayers,
            page: next.page,
            pageSize: next.pageSize,
            calculatedAt: next.calculatedAt
        )
    }
}

// MARK: - Query

/// One page of one ranking: the unit the cache and the network work with.
struct RankingQuery: Hashable {
    static let pageSize = 20

    let season: RankingSeason
    let communityId: String
    let category: RankingCategory
    let page: Int

    /// Identifies every page of the same season, community and category.
    var scopeKey: String {
        "\(season.year)-\(season.month)-\(communityId)-\(category.rawValue)"
    }

    func withPage(_ page: Int) -> RankingQuery {
        RankingQuery(season: season, communityId: communityId, category: category, page: page)
    }
}
