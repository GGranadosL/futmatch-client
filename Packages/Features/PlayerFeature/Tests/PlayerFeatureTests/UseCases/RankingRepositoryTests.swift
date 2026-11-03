import XCTest
@testable import PlayerFeature

private final class MockRankingService: RankingServiceProtocol {
    var result: Result<RankingBoard, Error> = .success(.stub())
    private(set) var requests: [RankingQuery] = []

    func fetchRanking(_ query: RankingQuery) async throws -> RankingBoard {
        requests.append(query)
        return try result.get()
    }
}

final class RankingRepositoryTests: XCTestCase {
    private var directory: URL!
    private var cache: FileRankingCacheStore!
    private var service: MockRankingService!
    private var now = Date(timeIntervalSince1970: 1_000_000)

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ranking-tests-\(UUID().uuidString)", isDirectory: true)
        cache = FileRankingCacheStore(directory: directory)
        service = MockRankingService()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func makeSUT() -> RankingRepository {
        RankingRepository(service: service, cache: cache, now: { [unowned self] in self.now })
    }

    func test_withinTimeToLive_usesCacheWithoutNetwork() async throws {
        let sut = makeSUT()
        _ = try await sut.fetchRanking(.stub(), force: false)
        now += RankingRepository.timeToLive - 1

        _ = try await sut.fetchRanking(.stub(), force: false)

        XCTAssertEqual(service.requests.count, 1)
    }

    func test_emptyResult_isAValidCacheEntry() async throws {
        service.result = .success(.stub(players: []))
        let sut = makeSUT()
        _ = try await sut.fetchRanking(.stub(), force: false)

        let second = try await sut.fetchRanking(.stub(), force: false)

        XCTAssertEqual(service.requests.count, 1)
        XCTAssertTrue(second.players.isEmpty)
    }

    func test_readingCache_doesNotRenewTheTimeToLive() async throws {
        let sut = makeSUT()
        _ = try await sut.fetchRanking(.stub(), force: false)
        now += RankingRepository.timeToLive / 2
        _ = try await sut.fetchRanking(.stub(), force: false)
        now += RankingRepository.timeToLive / 2

        _ = try await sut.fetchRanking(.stub(), force: false)

        XCTAssertEqual(service.requests.count, 2, "Six hours count from the save, not from the last read")
    }

    func test_expiredAndOffline_fallsBackToSnapshot() async throws {
        let sut = makeSUT()
        _ = try await sut.fetchRanking(.stub(), force: false)
        now += RankingRepository.timeToLive + 1
        service.result = .failure(TestError.boom)

        let board = try await sut.fetchRanking(.stub(), force: false)

        XCTAssertEqual(board, .stub())
    }

    func test_forcedRefresh_ignoresTimeToLiveAndSurfacesErrors() async throws {
        let sut = makeSUT()
        _ = try await sut.fetchRanking(.stub(), force: false)
        service.result = .failure(TestError.boom)

        do {
            _ = try await sut.fetchRanking(.stub(), force: true)
            XCTFail("Expected the refresh error")
        } catch {
            XCTAssertEqual(service.requests.count, 2)
        }
        XCTAssertEqual(sut.cachedRanking(.stub()), .stub(), "A failed refresh keeps the stored page")
    }

    func test_refreshingPageOne_dropsLaterPagesOfThatScopeOnly() async throws {
        let sut = makeSUT()
        let goals = RankingQuery.stub(category: .goals, page: 2)
        let october = RankingQuery.stub(season: RankingSeason(year: 2026, month: 10), page: 2)
        _ = try await sut.fetchRanking(.stub(page: 1), force: false)
        _ = try await sut.fetchRanking(.stub(page: 2), force: false)
        _ = try await sut.fetchRanking(goals, force: false)
        _ = try await sut.fetchRanking(october, force: false)

        _ = try await sut.fetchRanking(.stub(page: 1), force: true)

        XCTAssertNotNil(sut.cachedRanking(.stub(page: 1)))
        XCTAssertNil(sut.cachedRanking(.stub(page: 2)))
        XCTAssertNotNil(sut.cachedRanking(goals))
        XCTAssertNotNil(sut.cachedRanking(october))
    }

    func test_clearAll_removesEveryScope() async throws {
        let sut = makeSUT()
        _ = try await sut.fetchRanking(.stub(), force: false)

        cache.clearAll()

        XCTAssertNil(sut.cachedRanking(.stub()))
    }
}
