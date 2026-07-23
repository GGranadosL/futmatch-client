import XCTest
@testable import AdminFeature

final class CancelAdminMatchUseCaseTests: XCTestCase {

    func test_execute_forwardsMatchIdAndReasonToRepository() async throws {
        let repo = MockAdminMatchRepository()
        let sut = CancelAdminMatchUseCase(repository: repo)

        try await sut.execute(matchId: "match-1", reason: "Razones climáticas.")

        XCTAssertEqual(repo.cancelMatchCallCount, 1)
        XCTAssertEqual(repo.lastCancelMatchId, "match-1")
        XCTAssertEqual(repo.lastCancelReason, "Razones climáticas.")
    }

    func test_execute_trimsWhitespaceFromReason() async throws {
        let repo = MockAdminMatchRepository()
        let sut = CancelAdminMatchUseCase(repository: repo)

        try await sut.execute(matchId: "match-1", reason: "  Cancha no disponible.  ")

        XCTAssertEqual(repo.lastCancelReason, "Cancha no disponible.")
    }

    func test_execute_throwsInvalidReason_whenReasonIsBlank() async {
        let repo = MockAdminMatchRepository()
        let sut = CancelAdminMatchUseCase(repository: repo)

        do {
            try await sut.execute(matchId: "match-1", reason: "   \n  ")
            XCTFail("Expected invalidReason error")
        } catch {
            XCTAssertEqual(error as? CancelAdminMatchError, .invalidReason)
        }
        XCTAssertEqual(repo.cancelMatchCallCount, 0, "Repository must not be called with a blank reason")
    }

    func test_execute_throwsInvalidReason_whenReasonExceedsMaxLength() async {
        let repo = MockAdminMatchRepository()
        let sut = CancelAdminMatchUseCase(repository: repo)
        let tooLong = String(repeating: "a", count: CancelAdminMatchUseCase.maxReasonLength + 1)

        do {
            try await sut.execute(matchId: "match-1", reason: tooLong)
            XCTFail("Expected invalidReason error")
        } catch {
            XCTAssertEqual(error as? CancelAdminMatchError, .invalidReason)
        }
        XCTAssertEqual(repo.cancelMatchCallCount, 0)
    }

    func test_execute_allowsReasonAtExactlyMaxLength() async throws {
        let repo = MockAdminMatchRepository()
        let sut = CancelAdminMatchUseCase(repository: repo)
        let maxed = String(repeating: "a", count: CancelAdminMatchUseCase.maxReasonLength)

        try await sut.execute(matchId: "match-1", reason: maxed)

        XCTAssertEqual(repo.cancelMatchCallCount, 1)
        XCTAssertEqual(repo.lastCancelReason, maxed)
    }

    func test_execute_propagatesRepositoryError() async {
        let repo = MockAdminMatchRepository()
        repo.cancelMatchResult = .failure(TestError.boom)
        let sut = CancelAdminMatchUseCase(repository: repo)

        do {
            try await sut.execute(matchId: "match-1", reason: "Otro motivo")
            XCTFail("Expected repository error")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
