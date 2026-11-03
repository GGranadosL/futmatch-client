import XCTest
@testable import PlayerFeature

final class RankingModelTests: XCTestCase {

    // MARK: - Seasons

    func test_selectableSeasons_areCurrentPlusThreePrevious() {
        let seasons = RankingSeason(year: 2026, month: 11).selectableSeasons
        XCTAssertEqual(seasons, [
            RankingSeason(year: 2026, month: 11),
            RankingSeason(year: 2026, month: 10),
            RankingSeason(year: 2026, month: 9),
            RankingSeason(year: 2026, month: 8)
        ])
    }

    func test_selectableSeasons_inJanuary_reachIntoThePreviousYear() {
        let seasons = RankingSeason(year: 2027, month: 1).selectableSeasons
        XCTAssertEqual(seasons, [
            RankingSeason(year: 2027, month: 1),
            RankingSeason(year: 2026, month: 12),
            RankingSeason(year: 2026, month: 11),
            RankingSeason(year: 2026, month: 10)
        ])
    }

    func test_currentSeason_usesTheDevicesTimeZone() throws {
        // 2026-12-01 03:00 UTC is still November in Mexico City (UTC−6).
        let instant = Date(timeIntervalSince1970: 1_796_094_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Mexico_City"))

        XCTAssertEqual(RankingSeason.current(now: instant, calendar: calendar), RankingSeason(year: 2026, month: 11))
    }

    // MARK: - Home summary

    func test_victoriesToTarget_isTheGapToTieTheNextScore() {
        XCTAssertEqual(HomeRanking.stub(victories: 7, nextTarget: RankingTarget(position: 4, victories: 8)).victoriesToTarget, 1)
    }

    func test_victoriesToTarget_withoutHigherScore_isNil() {
        XCTAssertNil(HomeRanking.stub(position: 1, nextTarget: nil).victoriesToTarget)
        XCTAssertNil(HomeRanking.stub(victories: 8, nextTarget: RankingTarget(position: 1, victories: 8)).victoriesToTarget)
    }

    func test_homeRankingDTO_notParticipating_dropsPositionAndTarget() {
        let dto = HomeRankingDTO(
            period: RankingPeriodDTO(year: 2026, month: 11, startTime: nil, endTimeExclusive: nil, timeZone: nil),
            community: nil, category: "VICTORIES", status: "NOT_PARTICIPATING",
            position: 3, victories: nil, matchesPlayed: nil,
            nextTarget: RankingTargetDTO(position: 2, victories: 1), calculatedAt: nil
        )

        let ranking = dto.toDomain()

        XCTAssertEqual(ranking?.status, .notParticipating)
        XCTAssertNil(ranking?.position)
        XCTAssertNil(ranking?.nextTarget)
        XCTAssertEqual(ranking?.victories, 0)
        XCTAssertEqual(ranking?.community, .global)
    }

    func test_homeRankingDTO_rankedWithoutPosition_isUnusable() {
        let dto = HomeRankingDTO(
            period: RankingPeriodDTO(year: 2026, month: 11, startTime: nil, endTimeExclusive: nil, timeZone: nil),
            community: nil, category: nil, status: "RANKED",
            position: nil, victories: 3, matchesPlayed: 4, nextTarget: nil, calculatedAt: nil
        )
        XCTAssertNil(dto.toDomain())
    }

    func test_homeData_malformedRanking_doesNotBreakHome() throws {
        let json = """
        {"profile":{"greetingName":"Ana","level":"BEGINNER","averageScore":0},
         "suggestedMatches":[],"ranking":{"period":"broken"}}
        """
        let dto = try JSONDecoder().decode(HomeDataDTO.self, from: Data(json.utf8))
        XCTAssertNil(dto.ranking)
        XCTAssertEqual(dto.profile.greetingName, "Ana")
    }

    // MARK: - Board

    func test_hasMore_comparesLoadedPagesWithTotal() {
        XCTAssertTrue(RankingBoard.stub(totalPlayers: 21, page: 1).hasMore)
        XCTAssertFalse(RankingBoard.stub(totalPlayers: 20, page: 1).hasMore)
    }

    func test_appending_addsNewRowsWithoutDuplicates() {
        let first = RankingBoard.stub(players: [.stub(id: "a"), .stub(id: "b")], totalPlayers: 30, page: 1)
        let second = RankingBoard.stub(players: [.stub(id: "b"), .stub(id: "c")], totalPlayers: 30, page: 2)

        let merged = first.appending(second)

        XCTAssertEqual(merged.players.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(merged.page, 2)
    }

    func test_currentUserIsListed_matchesById() {
        let me = RankingPlayer.stub(id: "me", position: 27)
        XCTAssertFalse(RankingBoard.stub(players: [.stub(id: "a")], currentUser: me).currentUserIsListed)
        XCTAssertTrue(RankingBoard.stub(players: [.stub(id: "a"), me], currentUser: me).currentUserIsListed)
    }

    // MARK: - Strings

    func test_homeStatistics_pluralizesEachCount() {
        let single = L10n.HomeRanking.statistics(victories: 1, matchesPlayed: 1)
        let many = L10n.HomeRanking.statistics(victories: 7, matchesPlayed: 12)
        XCTAssertNotEqual(single, many)
        XCTAssertTrue(single.contains("1"))
        XCTAssertTrue(many.contains("7") && many.contains("12"))
        XCTAssertFalse(single.contains("%"), "Plural variation didn't resolve: \(single)")
    }

    func test_flag_rejectsInvalidCodes() {
        XCTAssertEqual(RankingFormatting.flag(for: "mx"), "🇲🇽")
        XCTAssertNil(RankingFormatting.flag(for: "MEX"))
        XCTAssertNil(RankingFormatting.flag(for: nil))
    }
}
