import XCTest
@testable import PlayerFeature

final class MatchInvitesPreferenceUseCasesTests: XCTestCase {

    func test_get_returnsRepositoryValue() async throws {
        let repo = MockNotificationPreferencesRepository()
        repo.stubbedEnabled = false
        let sut = GetMatchInvitesEnabledUseCase(repository: repo)

        let enabled = try await sut.execute()

        XCTAssertFalse(enabled)
    }

    func test_get_propagatesError() async {
        let repo = MockNotificationPreferencesRepository()
        repo.fetchError = StubError()
        let sut = GetMatchInvitesEnabledUseCase(repository: repo)

        do {
            _ = try await sut.execute()
            XCTFail("Expected an error")
        } catch {
            XCTAssertTrue(error is StubError)
        }
    }

    func test_set_sendsValueToRepository() async throws {
        let repo = MockNotificationPreferencesRepository()
        let sut = SetMatchInvitesEnabledUseCase(repository: repo)

        try await sut.execute(false)

        XCTAssertEqual(repo.setValues, [false])
    }
}
