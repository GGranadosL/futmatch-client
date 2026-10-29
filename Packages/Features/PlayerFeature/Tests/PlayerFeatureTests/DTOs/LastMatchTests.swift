import XCTest
@testable import PlayerFeature
import SharedModels

final class LastMatchTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func makeMatch(playedAt: Date, teamA: MatchTeamVisual? = nil, teamB: MatchTeamVisual? = nil) -> LastMatch {
        LastMatch(matchId: "m", fieldName: "La Jaula", playedAt: playedAt, outcome: .win,
                  teamAScore: 9, teamBScore: 13, teamA: teamA, teamB: teamB)
    }

    private func date(_ day: Int, hour: Int = 19) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private let locale = Locale(identifier: "en_US_POSIX")

    private func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = calendar.timeZone
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    func test_relativeDateLabel_sameDay_isTodayLabel() {
        let played = date(19, hour: 8)
        let label = makeMatch(playedAt: played).relativeDateLabel(now: date(19, hour: 22), calendar: calendar, locale: locale)
        XCTAssertEqual(label, L10n.LastMatch.todayAt(time(played)))
    }

    func test_relativeDateLabel_previousDay_isYesterdayLabel() {
        let played = date(18)
        let label = makeMatch(playedAt: played).relativeDateLabel(now: date(19, hour: 1), calendar: calendar, locale: locale)
        XCTAssertEqual(label, L10n.LastMatch.yesterdayAt(time(played)))
    }

    func test_relativeDateLabel_olderMatch_usesDayCount() {
        let played = date(1)
        let label = makeMatch(playedAt: played).relativeDateLabel(now: date(19), calendar: calendar, locale: locale)
        XCTAssertEqual(label, L10n.LastMatch.daysAgoAt(18, time(played)))
    }

    func test_teamNames_fallBackToLocalizedLabels_whenNoVisuals() {
        let match = makeMatch(playedAt: date(1))
        XCTAssertEqual(match.teamAName, L10n.Matches.teamA)
        XCTAssertEqual(match.teamBName, L10n.Matches.teamB)
    }

    func test_teamNames_useSnapshot_whenPresent() {
        let match = makeMatch(
            playedAt: date(1),
            teamA: MatchTeamVisual(name: "Les Bleus", colorHex: "#0066FF"),
            teamB: MatchTeamVisual(name: "Los Blancos", colorHex: nil)
        )
        XCTAssertEqual(match.teamAName, "Les Bleus")
        XCTAssertEqual(match.teamBName, "Los Blancos")
    }

    // MARK: - DTO

    private func decode(_ json: String) throws -> HomeLastMatchDTO {
        try JSONDecoder().decode(HomeLastMatchDTO.self, from: Data(json.utf8))
    }

    private let base = ##""matchId":"m","fieldId":"f","fieldName":"La Jaula","playedAt":1760000000000,"outcome":"WIN","teamAScore":9,"teamBScore":13"##

    func test_dto_withoutTeamIdentities_hasNilVisuals() throws {
        let dto = try decode("{\(base)}")
        XCTAssertNil(dto.toDomain().teamA)
        XCTAssertNil(dto.toDomain().teamB)
    }

    func test_dto_readsTeamVisualsSnapshot() throws {
        let dto = try decode(##"{\##(base),"teamVisuals":{"teamA":{"name":"Les Bleus","color":"#0066FF"},"teamB":{"name":"Red Devils","color":"#EF1B23"}}}"##)
        XCTAssertEqual(dto.toDomain().teamA?.name, "Les Bleus")
        XCTAssertEqual(dto.toDomain().teamB?.colorHex, "#EF1B23")
    }

    func test_dto_readsTopLevelTeams() throws {
        let dto = try decode(##"{\##(base),"teamA":{"name":"Les Bleus","color":"#0066FF"},"teamB":{"name":"Red Devils","color":"#EF1B23"}}"##)
        XCTAssertEqual(dto.toDomain().teamA?.name, "Les Bleus")
    }

    // MARK: - Public profile mapping

    private func publicLast(outcome: String, teamA: PlayerLastMatchTeam? = nil) -> PlayerLastMatch {
        PlayerLastMatch(matchId: "m", fieldId: "f", fieldName: "La Jaula", playedAt: date(19),
                        outcome: outcome, teamAScore: 9, teamBScore: 13, teamA: teamA)
    }

    func test_publicProfile_mapsOutcomeIgnoringCase() {
        XCTAssertEqual(LastMatch(publicProfile: publicLast(outcome: "win")).outcome, .win)
        XCTAssertEqual(LastMatch(publicProfile: publicLast(outcome: "LOSE")).outcome, .loss)
        XCTAssertEqual(LastMatch(publicProfile: publicLast(outcome: "LOSS")).outcome, .loss)
        XCTAssertEqual(LastMatch(publicProfile: publicLast(outcome: "DRAW")).outcome, .draw)
    }

    func test_publicProfile_keepsTeamIdentity() {
        let match = LastMatch(publicProfile: publicLast(outcome: "WIN", teamA: PlayerLastMatchTeam(name: "Les Bleus", colorHex: "#0066FF")))
        XCTAssertEqual(match.teamAName, "Les Bleus")
        XCTAssertEqual(match.teamA?.colorHex, "#0066FF")
        XCTAssertEqual(match.teamBName, L10n.Matches.teamB)
    }
}
