import XCTest
@testable import AdminFeature

final class AdminMatchListGroupingTests: XCTestCase {

    private let calendar = Calendar.current

    /// Fixed reference "now": today at 14:00.
    private var now: Date {
        calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
    }

    private func date(daysFromToday days: Int, hour: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    // MARK: - Upcoming

    func test_upcoming_todayComesFirst_thenFutureDaysAscending() {
        let matches: [AdminMatch] = [
            .stub(id: "next-week", startDate: date(daysFromToday: 7, hour: 20)),
            .stub(id: "tomorrow",  startDate: date(daysFromToday: 1, hour: 20)),
            .stub(id: "today",     startDate: date(daysFromToday: 0, hour: 20))
        ]

        let sections = AdminMatchListGrouping.sections(matches, tab: .upcoming, now: now)

        XCTAssertEqual(sections.count, 3)
        XCTAssertEqual(sections[0].matches.map(\.id), ["today"])
        XCTAssertEqual(sections[1].matches.map(\.id), ["tomorrow"])
        XCTAssertEqual(sections[2].matches.map(\.id), ["next-week"])
        XCTAssertEqual(sections[0].title, L10n.AdminMatches.sectionToday)
        XCTAssertEqual(sections[1].title, L10n.AdminMatches.sectionTomorrow)
    }

    func test_upcoming_matchesWithinADay_areSortedByStartTime() {
        let matches: [AdminMatch] = [
            .stub(id: "late",  startDate: date(daysFromToday: 0, hour: 22)),
            .stub(id: "early", startDate: date(daysFromToday: 0, hour: 8)),
            .stub(id: "mid",   startDate: date(daysFromToday: 0, hour: 16))
        ]

        let sections = AdminMatchListGrouping.sections(matches, tab: .upcoming, now: now)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].matches.map(\.id), ["early", "mid", "late"])
    }

    func test_upcoming_stalePastMatches_goAfterTodayAndFuture() {
        let matches: [AdminMatch] = [
            .stub(id: "yesterday", startDate: date(daysFromToday: -1, hour: 20)),
            .stub(id: "today",     startDate: date(daysFromToday: 0, hour: 20)),
            .stub(id: "last-week", startDate: date(daysFromToday: -7, hour: 20))
        ]

        let sections = AdminMatchListGrouping.sections(matches, tab: .upcoming, now: now)

        XCTAssertEqual(sections.map { $0.matches.map(\.id) }, [["today"], ["yesterday"], ["last-week"]])
    }

    // MARK: - Finished

    func test_finished_mostRecentDayFirst() {
        let matches: [AdminMatch] = [
            .stub(id: "old",    status: .completed, startDate: date(daysFromToday: -10, hour: 20)),
            .stub(id: "today",  status: .completed, startDate: date(daysFromToday: 0, hour: 10)),
            .stub(id: "recent", status: .completed, startDate: date(daysFromToday: -2, hour: 20))
        ]

        let sections = AdminMatchListGrouping.sections(matches, tab: .finished, now: now)

        XCTAssertEqual(sections.map { $0.matches.map(\.id) }, [["today"], ["recent"], ["old"]])
    }

    // MARK: - Canceled

    func test_canceled_futureFirstAscending_thenPastDescending() {
        let matches: [AdminMatch] = [
            .stub(id: "past",       status: .canceled, startDate: date(daysFromToday: -3, hour: 20)),
            .stub(id: "future",     status: .canceled, startDate: date(daysFromToday: 5, hour: 20)),
            .stub(id: "today",      status: .canceled, startDate: date(daysFromToday: 0, hour: 9)),
            .stub(id: "older-past", status: .canceled, startDate: date(daysFromToday: -8, hour: 20))
        ]

        let sections = AdminMatchListGrouping.sections(matches, tab: .canceled, now: now)

        XCTAssertEqual(
            sections.map { $0.matches.map(\.id) },
            [["today"], ["future"], ["past"], ["older-past"]]
        )
    }

    func test_canceled_todayMatchesEarlierThanNow_stayInTodaySection() {
        // A match canceled today at 09:00 (now is 14:00) must still group under
        // today's section, not fall into the "past" block as a duplicate day.
        let matches: [AdminMatch] = [
            .stub(id: "today-morning", status: .canceled, startDate: date(daysFromToday: 0, hour: 9)),
            .stub(id: "today-evening", status: .canceled, startDate: date(daysFromToday: 0, hour: 20))
        ]

        let sections = AdminMatchListGrouping.sections(matches, tab: .canceled, now: now)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].matches.map(\.id), ["today-morning", "today-evening"])
    }

    // MARK: - Section identity

    func test_sections_haveStableIdentityAcrossRecomputation() {
        let matches: [AdminMatch] = [
            .stub(id: "a", startDate: date(daysFromToday: 0, hour: 20)),
            .stub(id: "b", startDate: date(daysFromToday: 1, hour: 20))
        ]

        let first  = AdminMatchListGrouping.sections(matches, tab: .upcoming, now: now)
        let second = AdminMatchListGrouping.sections(matches, tab: .upcoming, now: now)

        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    // MARK: - Tab filtering

    func test_tabFilter_routesEachStatusToItsTab() {
        let matches: [AdminMatch] = [
            .stub(id: "scheduled",   status: .scheduled),
            .stub(id: "in-progress", status: .inProgress),
            .stub(id: "completed",   status: .completed),
            .stub(id: "canceled",    status: .canceled)
        ]

        XCTAssertEqual(AdminMatchListTab.upcoming.filter(matches).map(\.id), ["scheduled", "in-progress"])
        XCTAssertEqual(AdminMatchListTab.finished.filter(matches).map(\.id), ["completed"])
        XCTAssertEqual(AdminMatchListTab.canceled.filter(matches).map(\.id), ["canceled"])
    }
}

// MARK: - AdminMatchStatus backend parsing

final class AdminMatchStatusBackendParsingTests: XCTestCase {

    func test_backendInit_acceptsBothCancellationSpellings() {
        XCTAssertEqual(AdminMatchStatus(backend: "CANCELED"), .canceled)
        XCTAssertEqual(AdminMatchStatus(backend: "CANCELLED"), .canceled)
    }

    func test_backendInit_mapsKnownStatuses() {
        XCTAssertEqual(AdminMatchStatus(backend: "SCHEDULED"), .scheduled)
        XCTAssertEqual(AdminMatchStatus(backend: "IN_PROGRESS"), .inProgress)
        XCTAssertEqual(AdminMatchStatus(backend: "COMPLETED"), .completed)
    }

    func test_backendInit_isCaseInsensitive_andDefaultsToScheduled() {
        XCTAssertEqual(AdminMatchStatus(backend: "cancelled"), .canceled)
        XCTAssertEqual(AdminMatchStatus(backend: "SOMETHING_NEW"), .scheduled)
    }
}
