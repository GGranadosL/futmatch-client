import XCTest
@testable import OnboardingFeature

// MARK: - SaveOnboardingDraftUseCase

final class SaveOnboardingDraftUseCaseTests: XCTestCase {

    func test_execute_forwardsDraftAndPassword() async throws {
        let repo = MockOnboardingRepository()
        let sut = SaveOnboardingDraftUseCase(repository: repo)
        let draft = OnboardingDraft.freshStub(email: "a@b.com")

        try await sut.execute(draft, password: "secret")

        XCTAssertEqual(repo.saveDraftCallCount, 1)
        XCTAssertEqual(repo.lastSavedDraft?.email, "a@b.com")
        XCTAssertEqual(repo.lastSavedPassword, "secret")
    }

    func test_execute_propagatesError() async {
        let repo = MockOnboardingRepository()
        repo.saveDraftError = TestError.boom
        let sut = SaveOnboardingDraftUseCase(repository: repo)

        do {
            try await sut.execute(.freshStub(), password: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}

// MARK: - GetOnboardingDraftUseCase

final class GetOnboardingDraftUseCaseTests: XCTestCase {

    func test_execute_returnsValidDraft() async throws {
        let repo = MockOnboardingRepository()
        repo.getDraftResult = .success((draft: .freshStub(email: "a@b.com"), password: "pw"))
        let sut = GetOnboardingDraftUseCase(repository: repo)

        let result = try await sut.execute()

        XCTAssertEqual(result?.draft.email, "a@b.com")
        XCTAssertEqual(result?.password, "pw")
        XCTAssertEqual(repo.clearDraftCallCount, 0)
    }

    func test_execute_expiredDraft_clearsAndReturnsNil() async throws {
        let repo = MockOnboardingRepository()
        repo.getDraftResult = .success((draft: .expiredStub(), password: nil))
        let sut = GetOnboardingDraftUseCase(repository: repo)

        let result = try await sut.execute()

        XCTAssertNil(result)
        XCTAssertEqual(repo.clearDraftCallCount, 1)
    }

    func test_execute_noDraft_returnsNil() async throws {
        let repo = MockOnboardingRepository()
        repo.getDraftResult = .success(nil)
        let sut = GetOnboardingDraftUseCase(repository: repo)

        let result = try await sut.execute()

        XCTAssertNil(result)
        XCTAssertEqual(repo.clearDraftCallCount, 0)
    }
}

// MARK: - ClearOnboardingDraftUseCase

final class ClearOnboardingDraftUseCaseTests: XCTestCase {

    func test_execute_delegatesToRepository() async throws {
        let repo = MockOnboardingRepository()
        let sut = ClearOnboardingDraftUseCase(repository: repo)

        try await sut.execute()

        XCTAssertEqual(repo.clearDraftCallCount, 1)
    }

    func test_execute_propagatesError() async {
        let repo = MockOnboardingRepository()
        repo.clearDraftError = TestError.boom
        let sut = ClearOnboardingDraftUseCase(repository: repo)

        do {
            try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? TestError, .boom)
        }
    }
}
