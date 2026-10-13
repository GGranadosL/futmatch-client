import XCTest
@testable import AdminFeature

final class AdminDashboardComposerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func match(_ id: String, _ status: AdminMatchStatus, hoursFromNow: Double) -> AdminMatch {
        .stub(id: id, status: status, startDate: now.addingTimeInterval(hoursFromNow * 3600))
    }

    func test_pendingResult_isShown_evenWhenOutsideTheThreeHourWindow() {
        let matches = [match("old-pending", .pendingResult, hoursFromNow: -30)]

        let dashboard = AdminDashboardComposer.compose(fieldsCount: 2, matches: matches, now: now)

        XCTAssertEqual(dashboard.upcomingMatches.map(\.id), ["old-pending"])
        XCTAssertEqual(dashboard.upcomingMatches.first?.status, .pendingResult)
    }

    func test_scheduledMatchesFarAway_areCountedButNotListed() {
        let matches = [match("later", .scheduled, hoursFromNow: 48), match("soon", .scheduled, hoursFromNow: 1)]

        let dashboard = AdminDashboardComposer.compose(fieldsCount: 0, matches: matches, now: now)

        XCTAssertEqual(dashboard.scheduledMatchesCount, 2)
        XCTAssertEqual(dashboard.upcomingMatches.map(\.id), ["soon"])
    }

    func test_order_isLiveFirst_thenPendingResult_thenByStartTime() {
        let matches = [
            match("scheduled-soon", .scheduled, hoursFromNow: 1),
            match("pending", .pendingResult, hoursFromNow: -5),
            match("live", .inProgress, hoursFromNow: -1),
            match("scheduled-sooner", .scheduled, hoursFromNow: 0.5)
        ]

        let dashboard = AdminDashboardComposer.compose(fieldsCount: 0, matches: matches, now: now)

        XCTAssertEqual(dashboard.upcomingMatches.map(\.id), ["live", "pending", "scheduled-sooner", "scheduled-soon"])
        XCTAssertEqual(dashboard.ongoingFullMatches.map(\.id), dashboard.upcomingMatches.map(\.id))
    }

    func test_completedAndCanceledMatches_areExcluded() {
        let matches = [match("done", .completed, hoursFromNow: -1), match("canceled", .canceled, hoursFromNow: 1)]

        let dashboard = AdminDashboardComposer.compose(fieldsCount: 0, matches: matches, now: now)

        XCTAssertTrue(dashboard.upcomingMatches.isEmpty)
        XCTAssertEqual(dashboard.scheduledMatchesCount, 0)
    }
}
