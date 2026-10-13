import XCTest
@testable import AdminFeature

final class FetchTeamCatalogUseCaseTests: XCTestCase {

    private final class MockTeamCatalogRepository: TeamCatalogRepositoryProtocol {
        var result: Result<[TeamVisualCatalogItem], Error> = .success([])
        var fetchCallCount = 0
        func fetchTeamCatalog() async throws -> [TeamVisualCatalogItem] {
            fetchCallCount += 1
            return try result.get()
        }
    }

    private final class MockTeamCatalogCache: TeamCatalogCacheRepositoryProtocol {
        var stored: [TeamVisualCatalogItem] = []
        func saveTeams(_ items: [TeamVisualCatalogItem]) throws { stored = items }
        func loadTeams() -> [TeamVisualCatalogItem] { stored }
        func clearTeams() throws { stored = [] }
    }

    private struct NetworkDown: Error {}

    private func makeSUT(
        cached: [TeamVisualCatalogItem] = [],
        remote: Result<[TeamVisualCatalogItem], Error> = .success([])
    ) -> (FetchTeamCatalogUseCase, MockTeamCatalogRepository, MockTeamCatalogCache) {
        let repo = MockTeamCatalogRepository()
        repo.result = remote
        let cache = MockTeamCatalogCache()
        cache.stored = cached
        return (FetchTeamCatalogUseCase(repository: repo, cache: cache), repo, cache)
    }

    func test_execute_usesLocalCatalog_withoutHittingNetwork() async throws {
        let (sut, repo, _) = makeSUT(cached: [.stub(id: "local")], remote: .success([.stub(id: "remote")]))

        let result = try await sut.execute(forceRefresh: false)

        XCTAssertEqual(result.map(\.id), ["local"])
        XCTAssertEqual(repo.fetchCallCount, 0)
    }

    func test_execute_fetchesAndStores_whenLocalCatalogIsEmpty() async throws {
        let (sut, repo, cache) = makeSUT(remote: .success([.stub(id: "remote")]))

        let result = try await sut.execute(forceRefresh: false)

        XCTAssertEqual(result.map(\.id), ["remote"])
        XCTAssertEqual(repo.fetchCallCount, 1)
        XCTAssertEqual(cache.stored.map(\.id), ["remote"])
    }

    func test_execute_forceRefresh_replacesLocalCatalog() async throws {
        let (sut, repo, cache) = makeSUT(cached: [.stub(id: "old")], remote: .success([.stub(id: "new")]))

        let result = try await sut.execute(forceRefresh: true)

        XCTAssertEqual(result.map(\.id), ["new"])
        XCTAssertEqual(repo.fetchCallCount, 1)
        XCTAssertEqual(cache.stored.map(\.id), ["new"])
    }

    func test_execute_forceRefreshFailure_throwsAndKeepsStoredCatalog() async {
        let (sut, _, cache) = makeSUT(cached: [.stub(id: "old")], remote: .failure(NetworkDown()))

        do {
            _ = try await sut.execute(forceRefresh: true)
            XCTFail("Expected the refresh error to propagate")
        } catch {
            XCTAssertTrue(error is NetworkDown)
        }
        XCTAssertEqual(cache.stored.map(\.id), ["old"])
    }
}
