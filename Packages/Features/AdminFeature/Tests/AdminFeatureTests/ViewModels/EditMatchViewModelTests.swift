import XCTest
@testable import AdminFeature

@MainActor
final class EditMatchViewModelTests: XCTestCase {

    // MARK: - Mocks

    private final class MockUpdateAdminMatchUseCase: UpdateAdminMatchUseCaseProtocol {
        var stubbedMatch: AdminMatch = .stub()
        func execute(_ params: UpdateMatchParams) async throws -> AdminMatch { stubbedMatch }
    }

    private final class MockFetchFieldIdNamesUseCase: FetchFieldIdNamesUseCaseProtocol {
        var stubbedFields: [FieldIdName] = []
        func execute() async throws -> [FieldIdName] { stubbedFields }
    }

    private func makeSUT(minPlayers: Int, spotsTotal: Int) -> EditMatchViewModel {
        let sut = EditMatchViewModel(
            match: .stub(minPlayers: minPlayers, spotsTotal: spotsTotal),
            updateUseCase: MockUpdateAdminMatchUseCase(),
            fetchFieldIdNamesUseCase: MockFetchFieldIdNamesUseCase()
        )
        // Picked by `loadFields()` in the real flow; set directly so the test covers
        // validation rather than loading.
        sut.selectedField = .stub()
        return sut
    }

    // MARK: - Capacity validation

    /// Regression: matches that only start at full capacity used to be uneditable —
    /// `isValid` required `min < max`, so Save Changes stayed disabled forever.
    func test_isValid_isTrue_whenMinimumEqualsMaximum() {
        let sut = makeSUT(minPlayers: 10, spotsTotal: 10)

        XCTAssertTrue(sut.isValid)
    }

    func test_isValid_isTrue_whenMinimumIsBelowMaximum() {
        let sut = makeSUT(minPlayers: 6, spotsTotal: 10)

        XCTAssertTrue(sut.isValid)
    }

    func test_isValid_isFalse_whenMinimumExceedsMaximum() {
        let sut = makeSUT(minPlayers: 12, spotsTotal: 10)

        XCTAssertFalse(sut.isValid)
    }

    func test_isValid_isFalse_whenCapacityIsMissing() {
        let sut = makeSUT(minPlayers: 10, spotsTotal: 10)
        sut.maxPlayersText = ""

        XCTAssertFalse(sut.isValid)
    }

    // MARK: - Change tracking

    func test_hasChanges_isFalse_whenNothingWasEdited() {
        let sut = makeSUT(minPlayers: 6, spotsTotal: 10)

        XCTAssertFalse(sut.hasChanges)
    }

    func test_hasChanges_isTrue_whenCapacityIsEdited() {
        let sut = makeSUT(minPlayers: 6, spotsTotal: 10)

        sut.maxPlayersText = "12"

        XCTAssertTrue(sut.hasChanges)
    }

    func test_hasChanges_isTrue_whenLevelIsEdited() {
        let sut = makeSUT(minPlayers: 6, spotsTotal: 10)

        sut.selectedLevel = .advanced

        XCTAssertTrue(sut.hasChanges)
    }

    /// Blur reformats "150.00" into "$150.00". That's presentation, not an edit.
    func test_hasChanges_isFalse_whenPriceIsOnlyReformatted() {
        let sut = makeSUT(minPlayers: 6, spotsTotal: 10)

        sut.formatPriceOnBlur()

        XCTAssertFalse(sut.hasChanges)
    }

    func test_hasChanges_isTrue_whenPriceValueActuallyChanges() {
        let sut = makeSUT(minPlayers: 6, spotsTotal: 10)

        sut.priceText = "170.00"

        XCTAssertTrue(sut.hasChanges)
    }

    /// The date picker returns a full timestamp, so re-picking the same day must not
    /// count as an edit.
    func test_hasChanges_isFalse_whenSameDayIsRepicked() {
        let start = Date()
        let sut = EditMatchViewModel(
            match: .stub(startDate: start, minPlayers: 6, spotsTotal: 10),
            updateUseCase: MockUpdateAdminMatchUseCase(),
            fetchFieldIdNamesUseCase: MockFetchFieldIdNamesUseCase()
        )
        sut.selectedField = .stub()

        sut.date = start.addingTimeInterval(60)

        XCTAssertFalse(sut.hasChanges)
    }

    func test_hasChanges_isTrue_whenDayIsMoved() {
        let sut = makeSUT(minPlayers: 6, spotsTotal: 10)

        sut.date = sut.date.addingTimeInterval(60 * 60 * 24)

        XCTAssertTrue(sut.hasChanges)
    }

    /// `selectedField` is nil until the field list loads; that gap must not look like an
    /// edit, or Save would light up on a form the user hasn't touched.
    func test_hasChanges_isFalse_beforeFieldsFinishLoading() {
        let sut = EditMatchViewModel(
            match: .stub(minPlayers: 6, spotsTotal: 10),
            updateUseCase: MockUpdateAdminMatchUseCase(),
            fetchFieldIdNamesUseCase: MockFetchFieldIdNamesUseCase()
        )

        XCTAssertNil(sut.selectedField)
        XCTAssertFalse(sut.hasChanges)
    }
}
