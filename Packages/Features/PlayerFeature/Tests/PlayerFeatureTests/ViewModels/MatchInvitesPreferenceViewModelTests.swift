import XCTest
@testable import PlayerFeature

@MainActor
final class MatchInvitesPreferenceViewModelTests: XCTestCase {

    private func makeSUT(
        get: MockGetMatchInvitesEnabledUseCase = MockGetMatchInvitesEnabledUseCase(),
        set: MockSetMatchInvitesEnabledUseCase = MockSetMatchInvitesEnabledUseCase()
    ) -> MatchInvitesPreferenceViewModel {
        MatchInvitesPreferenceViewModel(getEnabledUseCase: get, setEnabledUseCase: set)
    }

    func test_load_takesServerValue() async {
        let get = MockGetMatchInvitesEnabledUseCase()
        get.result = .success(false)
        let sut = makeSUT(get: get)

        await sut.load()

        XCTAssertFalse(sut.isEnabled)
        XCTAssertTrue(sut.isLoaded)
    }

    func test_load_failure_keepsSwitchUnavailable() async {
        let get = MockGetMatchInvitesEnabledUseCase()
        get.result = .failure(StubError())
        let sut = makeSUT(get: get)

        await sut.load()

        XCTAssertFalse(sut.isLoaded)
    }

    func test_setEnabled_beforeLoad_doesNothing() async {
        let set = MockSetMatchInvitesEnabledUseCase()
        let sut = makeSUT(set: set)

        await sut.setEnabled(false)

        XCTAssertTrue(set.values.isEmpty)
        XCTAssertTrue(sut.isEnabled)
    }

    func test_setEnabled_success_savesNewValue() async {
        let set = MockSetMatchInvitesEnabledUseCase()
        let sut = makeSUT(set: set)
        await sut.load()

        await sut.setEnabled(false)

        XCTAssertEqual(set.values, [false])
        XCTAssertFalse(sut.isEnabled)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSaving)
    }

    func test_setEnabled_failure_revertsAndShowsError() async {
        let set = MockSetMatchInvitesEnabledUseCase()
        set.error = StubError()
        let sut = makeSUT(set: set)
        await sut.load()

        await sut.setEnabled(false)

        XCTAssertTrue(sut.isEnabled)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isSaving)
    }

    func test_setEnabled_sameValue_doesNotCallServer() async {
        let set = MockSetMatchInvitesEnabledUseCase()
        let sut = makeSUT(set: set)
        await sut.load()

        await sut.setEnabled(true)

        XCTAssertTrue(set.values.isEmpty)
    }
}
