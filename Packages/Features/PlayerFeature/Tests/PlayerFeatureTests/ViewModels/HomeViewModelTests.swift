import XCTest
import Combine
import SharedModels
@testable import PlayerFeature

// MARK: - MockHomeService

private final class MockHomeService: HomeServiceProtocol {
    var suggestedMatches: [MatchItem] = []
    var ranking: HomeRanking?
    var error: Error?
    private(set) var fetchCallCount = 0
    private(set) var requestedSeasons: [RankingSeason] = []

    func fetchHome(rankingSeason: RankingSeason) async throws -> HomeData {
        fetchCallCount += 1
        requestedSeasons.append(rankingSeason)
        if let error { throw error }
        return HomeData(
            greetingName: "Ivan",
            level: .beginner,
            averageScore: 0,
            profileImageUrl: nil,
            suggestedMatches: suggestedMatches,
            lastMatch: nil,
            ranking: ranking
        )
    }
}

private final class MockHomeRankingFlag: HomeRankingFlagProviding {
    let subject: CurrentValueSubject<Bool, Never>
    init(_ enabled: Bool) { subject = CurrentValueSubject(enabled) }
    var isEnabled: Bool { subject.value }
    var changes: AnyPublisher<Bool, Never> { subject.dropFirst().eraseToAnyPublisher() }
}

// MARK: - HomeViewModelTests

@MainActor
final class HomeViewModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: HomeViewModel.cacheKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: HomeViewModel.cacheKey)
        super.tearDown()
    }

    private func makeSUT(
        service: MockHomeService,
        flag: MockHomeRankingFlag = MockHomeRankingFlag(false),
        season: @escaping () -> RankingSeason = { RankingSeason(year: 2026, month: 11) }
    ) -> HomeViewModel {
        HomeViewModel(
            homeService: service,
            fetchMatchDetailUseCase: MockFetchMatchDetailUseCase(),
            rankingFlag: flag,
            currentRankingSeason: season
        )
    }

    // MARK: - Ranking

    func test_rankingFlag_startsFromCachedValueAndFollowsChanges() {
        let flag = MockHomeRankingFlag(false)
        let sut = makeSUT(service: MockHomeService(), flag: flag)
        XCTAssertFalse(sut.isRankingEnabled)

        flag.subject.send(true)

        XCTAssertTrue(sut.isRankingEnabled)
    }

    func test_load_asksForTheDevicesCurrentMonth() async {
        let service = MockHomeService()
        let sut = makeSUT(service: service, season: { RankingSeason(year: 2027, month: 1) })

        await sut.load()

        XCTAssertEqual(service.requestedSeasons, [RankingSeason(year: 2027, month: 1)])
    }

    func test_ranking_isShownOnlyForTheCurrentMonth() async {
        let service = MockHomeService()
        service.ranking = .stub(season: RankingSeason(year: 2026, month: 11))
        var current = RankingSeason(year: 2026, month: 11)
        let sut = makeSUT(service: service, season: { current })
        await sut.load()
        XCTAssertNotNil(sut.ranking)

        // The device's month rolls over while the stored summary is still November's.
        current = RankingSeason(year: 2026, month: 12)

        XCTAssertNil(sut.ranking, "Another month's stats must never be relabelled as current")
    }

    func test_failedRefresh_keepsHomeButAnOldMonthSummaryReadsUnavailable() async {
        let service = MockHomeService()
        service.suggestedMatches = [.stub(id: "a")]
        service.ranking = .stub(season: RankingSeason(year: 2026, month: 10))
        var current = RankingSeason(year: 2026, month: 10)
        let sut = makeSUT(service: service, season: { current })
        await sut.load()

        current = RankingSeason(year: 2026, month: 11)
        service.error = TestError.boom
        await sut.load()

        XCTAssertEqual(sut.suggestedMatches.map(\.id), ["a"])
        XCTAssertNil(sut.ranking)
        XCTAssertFalse(sut.loadFailed)
    }

    func test_rankingSummary_survivesTheHomeCache() async {
        let service = MockHomeService()
        service.ranking = .stub(season: RankingSeason(year: 2026, month: 11))
        await makeSUT(service: service).load()

        let reopened = makeSUT(service: MockHomeService())

        XCTAssertEqual(reopened.ranking, .stub(season: RankingSeason(year: 2026, month: 11)))
    }

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        _ condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    // MARK: - Suggestions vs enrolled matches

    func test_visibleSuggestions_hidesMatchesTheUserIsEnrolledIn() async {
        let service = MockHomeService()
        service.suggestedMatches = [.stub(id: "a"), .stub(id: "b"), .stub(id: "c")]
        let sut = makeSUT(service: service)
        await sut.load()

        let visible = sut.visibleSuggestions(excluding: ["b"])

        XCTAssertEqual(visible.map(\.id), ["a", "c"])
    }

    func test_visibleSuggestions_withNoEnrolledMatches_keepsEverySuggestion() async {
        let service = MockHomeService()
        service.suggestedMatches = [.stub(id: "a"), .stub(id: "b")]
        let sut = makeSUT(service: service)
        await sut.load()

        XCTAssertEqual(sut.visibleSuggestions(excluding: []).map(\.id), ["a", "b"])
    }

    // MARK: - Membership changes

    func test_membershipChange_reloadsHomeOnceForABurstOfNotifications() async {
        let service = MockHomeService()
        let sut = makeSUT(service: service)

        // One booking posts join, payment-confirmed and Firestore-joined in quick succession.
        for _ in 0..<3 {
            NotificationCenter.default.post(name: .matchMembershipDidChange, object: nil)
        }
        await waitUntil { service.fetchCallCount > 0 }
        // Give any extra (non-debounced) reload time to show up.
        try? await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(service.fetchCallCount, 1)
        _ = sut
    }

    func test_membershipChange_replacesStaleSuggestions() async {
        let service = MockHomeService()
        service.suggestedMatches = [.stub(id: "booked"), .stub(id: "other")]
        let sut = makeSUT(service: service)
        await sut.load()

        service.suggestedMatches = [.stub(id: "other")]
        NotificationCenter.default.post(name: .matchMembershipDidChange, object: nil)
        await waitUntil { sut.suggestedMatches.count == 1 }

        XCTAssertEqual(sut.suggestedMatches.map(\.id), ["other"])
    }
}
