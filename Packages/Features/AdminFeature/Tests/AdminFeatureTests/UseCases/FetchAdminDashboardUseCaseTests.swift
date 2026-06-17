import XCTest
@testable import AdminFeature

final class FetchAdminDashboardUseCaseTests: XCTestCase {

    func test_execute_returnsRepositoryDashboard() async throws {
        let repo = MockAdminDashboardRepository()
        let expected = AdminDashboard.stub(scheduledMatchesCount: 5, registeredVenuesCount: 4)
        repo.fetchDashboardResult = .success(expected)
        let sut = FetchAdminDashboardUseCase(repository: repo)

        let result = try await sut.execute()

        XCTAssertEqual(repo.fetchDashboardCallCount, 1)
        XCTAssertEqual(result, expected)
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockAdminDashboardRepository()
        repo.fetchDashboardResult = .failure(TestError.boom)
        let sut = FetchAdminDashboardUseCase(repository: repo)

        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
