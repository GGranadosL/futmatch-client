import XCTest
@testable import PlayerFeature

/// Home's "next match" card: the match being played wins over future ones.
final class NextMatchSelectionTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A 60-minute match starting `startsIn` minutes from `now` (negative = already started).
    private func match(_ id: String, _ status: MatchStatus, startsIn minutes: Double, hasEnd: Bool = true) -> MatchItem {
        let start = now.addingTimeInterval(minutes * 60)
        return MatchItem(
            id: id,
            venueName: "Cancha",
            timeRange: "",
            startDate: start,
            endDate: hasEnd ? start.addingTimeInterval(3600) : nil,
            price: "",
            matchType: "",
            spotsLeft: 0,
            matchStatus: status
        )
    }

    private func next(_ matches: [MatchItem]) -> String? {
        ReservedMatchesViewModel.nextMatch(in: matches, now: now)?.id
    }

    func test_noOngoing_returnsNearestFutureMatch() {
        XCTAssertEqual(next([
            match("later", .scheduled, startsIn: 300),
            match("soon", .scheduled, startsIn: 60),
            match("done", .completed, startsIn: -600)
        ]), "soon")
    }

    func test_inProgressMatch_winsOverFutureMatch() {
        XCTAssertEqual(next([
            match("soon", .scheduled, startsIn: 60),
            match("live", .inProgress, startsIn: -20)
        ]), "live")
    }

    /// Status sync runs every 15 min, so a started match may still say SCHEDULED.
    func test_scheduledMatchPastKickoff_isTreatedAsOngoing() {
        XCTAssertEqual(next([
            match("soon", .scheduled, startsIn: 60),
            match("started", .scheduled, startsIn: -10)
        ]), "started")
    }

    func test_matchPastItsEnd_isNotOngoing_evenIfStatusLags() {
        XCTAssertEqual(next([
            match("over", .inProgress, startsIn: -90),
            match("soon", .scheduled, startsIn: 60)
        ]), "soon")
    }

    func test_canceledOrPendingResult_isNeverShown() {
        XCTAssertNil(next([
            match("canceled", .canceled, startsIn: -10),
            match("pending", .pendingResult, startsIn: -90)
        ]))
    }

    // MARK: - Awaiting result

    func test_pendingResult_isAwaitingResult() {
        XCTAssertTrue(match("p", .pendingResult, startsIn: -90).isAwaitingResult(at: now))
    }

    /// Ended 4 min ago but the status sync hasn't run yet.
    func test_pastEnd_withLaggingStatus_isAwaitingResult() {
        XCTAssertTrue(match("s", .scheduled, startsIn: -64).isAwaitingResult(at: now))
        XCTAssertTrue(match("i", .inProgress, startsIn: -64).isAwaitingResult(at: now))
    }

    func test_notEndedOrClosed_isNotAwaitingResult() {
        XCTAssertFalse(match("live", .inProgress, startsIn: -20).isAwaitingResult(at: now))
        XCTAssertFalse(match("done", .completed, startsIn: -600).isAwaitingResult(at: now))
        XCTAssertFalse(match("off", .canceled, startsIn: -600).isAwaitingResult(at: now))
        XCTAssertFalse(match("cached", .scheduled, startsIn: -600, hasEnd: false).isAwaitingResult(at: now))
    }

    // MARK: - Card badge

    func test_badge_beforeKickoff_showsSpotsLeft() {
        let badge = match("m", .scheduled, startsIn: 60).availabilityBadge(spotsLeft: 9, at: now)
        XCTAssertEqual(badge.label, L10n.Matches.spotsLeft(9))
    }

    func test_badge_duringMatch_showsPlayingNow() {
        let badge = match("m", .scheduled, startsIn: -10).availabilityBadge(spotsLeft: 9, at: now)
        XCTAssertEqual(badge.label, L10n.NextGame.inProgress)
    }

    func test_badge_afterEnd_showsAwaitingResult() {
        let badge = match("m", .scheduled, startsIn: -64).availabilityBadge(spotsLeft: 9, at: now)
        XCTAssertEqual(badge.label, L10n.MatchStatus.pendingResult)
    }

    func test_scheduledWithoutEndDate_pastKickoff_isNotOngoing() {
        XCTAssertNil(next([match("cached", .scheduled, startsIn: -10, hasEnd: false)]))
    }
}
