import XCTest
import SharedModels
@testable import PlayerFeature

// MARK: - MockHomeService

private final class MockHomeService: HomeServiceProtocol {
    var suggestedMatches: [MatchItem] = []
    private(set) var fetchCallCount = 0

    func fetchHome() async throws -> HomeData {
        fetchCallCount += 1
        return HomeData(
            greetingName: "Ivan",
            level: .beginner,
            averageScore: 0,
            profileImageUrl: nil,
            suggestedMatches: suggestedMatches,
            lastMatch: nil
        )
    }
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

    private func makeSUT(service: MockHomeService) -> HomeViewModel {
        HomeViewModel(homeService: service, fetchMatchDetailUseCase: MockFetchMatchDetailUseCase())
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
