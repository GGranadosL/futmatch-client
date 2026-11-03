import XCTest
@testable import PlayerFeature

private final class MockLoadCachedRankingUseCase: LoadCachedRankingUseCaseProtocol {
    var boards: [RankingQuery: RankingBoard] = [:]
    func execute(_ query: RankingQuery) -> RankingBoard? { boards[query] }
}

/// Answers each query with a stubbed result. A query listed in `gatedQueries` waits until
/// released, to reproduce a slow response that arrives after the user switched selection.
private final class MockFetchRankingUseCase: FetchRankingUseCaseProtocol {
    private let lock = NSLock()
    private var _results: [RankingQuery: Result<RankingBoard, Error>] = [:]
    private var _gates: [RankingQuery: CheckedContinuation<Void, Never>] = [:]
    private var _requests: [(query: RankingQuery, force: Bool)] = []
    var gatedQueries: Set<RankingQuery> = []

    var results: [RankingQuery: Result<RankingBoard, Error>] {
        get { lock.withLock { _results } }
        set { lock.withLock { _results = newValue } }
    }
    var requests: [(query: RankingQuery, force: Bool)] { lock.withLock { _requests } }
    func isWaiting(_ query: RankingQuery) -> Bool { lock.withLock { _gates[query] != nil } }

    func execute(_ query: RankingQuery, force: Bool) async throws -> RankingBoard {
        lock.withLock { _requests.append((query, force)) }
        if gatedQueries.contains(query) {
            await withCheckedContinuation { continuation in
                lock.withLock { _gates[query] = continuation }
            }
        }
        guard let result = results[query] else { throw TestError.boom }
        return try result.get()
    }

    func release(_ query: RankingQuery) {
        let gate = lock.withLock { _gates.removeValue(forKey: query) }
        gate?.resume()
    }
}

@MainActor
final class RankingViewModelTests: XCTestCase {
    private let november = RankingSeason(year: 2026, month: 11)
    private let october = RankingSeason(year: 2026, month: 10)

    private func makeSUT(
        cached: MockLoadCachedRankingUseCase = MockLoadCachedRankingUseCase(),
        fetch: MockFetchRankingUseCase
    ) -> RankingViewModel {
        RankingViewModel(season: november, communityId: "global", loadCachedRanking: cached, fetchRanking: fetch)
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func test_start_opensOnVictoriesWithFourSeasons() async {
        let fetch = MockFetchRankingUseCase()
        fetch.results[.stub()] = .success(.stub())
        let sut = makeSUT(fetch: fetch)

        sut.start()
        await waitUntil { sut.board != nil }

        XCTAssertEqual(sut.category, .victories)
        XCTAssertEqual(sut.seasons.count, 4)
        XCTAssertEqual(sut.board, .stub())
        XCTAssertFalse(sut.isLoading)
    }

    func test_start_showsCachedFirstPageBeforeNetworkAnswers() {
        let cached = MockLoadCachedRankingUseCase()
        cached.boards[.stub()] = .stub(players: [.stub(id: "cached")])
        let fetch = MockFetchRankingUseCase()
        let sut = makeSUT(cached: cached, fetch: fetch)

        sut.start()

        XCTAssertEqual(sut.board?.players.map(\.id), ["cached"])
        XCTAssertFalse(sut.isLoading, "Cached rows replace the skeleton")
    }

    func test_selectSeason_keepsCategoryAndRestartsAtPageOne() async {
        let fetch = MockFetchRankingUseCase()
        fetch.results[.stub(category: .goals)] = .success(.stub(category: .goals))
        fetch.results[.stub(season: october, category: .goals)] = .success(.stub(season: october, category: .goals))
        let sut = makeSUT(fetch: fetch)
        sut.start()
        sut.selectCategory(.goals)
        await waitUntil { sut.board?.category == .goals }

        sut.selectSeason(october)
        await waitUntil { sut.board?.period.season == self.october }

        XCTAssertEqual(sut.category, .goals)
        XCTAssertEqual(fetch.requests.last?.query, .stub(season: october, category: .goals, page: 1))
    }

    func test_selectSeason_outsideTheFourOptions_isIgnored() {
        let fetch = MockFetchRankingUseCase()
        let sut = makeSUT(fetch: fetch)
        sut.start()

        sut.selectSeason(RankingSeason(year: 2026, month: 7))

        XCTAssertEqual(sut.season, november)
    }

    func test_lateResponseForPreviousSelection_isDiscarded() async {
        let fetch = MockFetchRankingUseCase()
        let slow = RankingQuery.stub(category: .victories)
        fetch.gatedQueries = [slow]
        fetch.results[slow] = .success(.stub(category: .victories))
        fetch.results[.stub(category: .goals)] = .success(.stub(category: .goals))
        let sut = makeSUT(fetch: fetch)

        sut.start()
        await waitUntil { fetch.isWaiting(slow) }
        sut.selectCategory(.goals)
        await waitUntil { sut.board?.category == .goals }
        fetch.release(slow)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(sut.board?.category, .goals)
        XCTAssertFalse(sut.hasError)
        XCTAssertNil(sut.errorMessage, "A cancelled request never surfaces an error")
    }

    func test_loadMore_appendsWithoutDuplicates() async {
        let fetch = MockFetchRankingUseCase()
        fetch.results[.stub(page: 1)] = .success(.stub(players: [.stub(id: "a"), .stub(id: "b")], totalPlayers: 25, page: 1))
        fetch.results[.stub(page: 2)] = .success(.stub(players: [.stub(id: "b"), .stub(id: "c")], totalPlayers: 25, page: 2))
        let sut = makeSUT(fetch: fetch)
        sut.start()
        await waitUntil { sut.board != nil }

        sut.loadMore()
        await waitUntil { sut.board?.page == 2 }

        XCTAssertEqual(sut.board?.players.map(\.id), ["a", "b", "c"])
    }

    func test_loadMoreFailure_keepsRowsAndOffersRetry() async {
        let fetch = MockFetchRankingUseCase()
        fetch.results[.stub(page: 1)] = .success(.stub(players: [.stub(id: "a")], totalPlayers: 25, page: 1))
        let sut = makeSUT(fetch: fetch)
        sut.start()
        await waitUntil { sut.board != nil }

        sut.loadMore()
        await waitUntil { sut.loadMoreError }

        XCTAssertEqual(sut.board?.players.map(\.id), ["a"])
        XCTAssertEqual(sut.board?.page, 1)
        XCTAssertFalse(sut.hasError)
    }

    func test_firstLoadFailure_withNothingToShow_setsError() async {
        let fetch = MockFetchRankingUseCase()
        let sut = makeSUT(fetch: fetch)

        sut.start()
        await waitUntil { sut.hasError }

        XCTAssertNil(sut.board)
        XCTAssertNil(sut.errorMessage)
    }

    func test_refreshFailure_keepsRowsAndRaisesToast() async {
        let fetch = MockFetchRankingUseCase()
        fetch.results[.stub()] = .success(.stub())
        let sut = makeSUT(fetch: fetch)
        sut.start()
        await waitUntil { sut.board != nil }
        fetch.results[.stub()] = .failure(TestError.boom)

        await sut.refresh()

        XCTAssertEqual(sut.board, .stub())
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(fetch.requests.last?.force, true)
    }
}
