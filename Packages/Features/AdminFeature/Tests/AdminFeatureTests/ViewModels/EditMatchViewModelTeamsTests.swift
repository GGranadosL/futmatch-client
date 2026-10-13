import XCTest
@testable import AdminFeature

@MainActor
final class EditMatchViewModelTeamsTests: XCTestCase {

    private final class MockUpdate: UpdateAdminMatchUseCaseProtocol {
        var receivedParams: UpdateMatchParams?
        func execute(_ params: UpdateMatchParams) async throws -> AdminMatch {
            receivedParams = params
            return .stub()
        }
    }

    private final class MockFields: FetchFieldIdNamesUseCaseProtocol {
        func execute() async throws -> [FieldIdName] { [] }
    }

    private final class MockCatalog: FetchTeamCatalogUseCaseProtocol {
        var teams: [TeamVisualCatalogItem] = []
        func execute(forceRefresh: Bool) async throws -> [TeamVisualCatalogItem] { teams }
    }

    private let bleus = TeamVisualCatalogItem.stub(id: "bleus", name: "Les Bleus", colorHex: "#315DA8")
    private let devils = TeamVisualCatalogItem.stub(id: "devils", name: "Red Devils", colorHex: "#B43C4A")
    private let blacks = TeamVisualCatalogItem.stub(id: "blacks", name: "All Blacks", colorHex: "#292D34")

    private func makeSUT(visuals: AdminMatchTeamVisuals?, update: MockUpdate = MockUpdate()) -> (EditMatchViewModel, MockCatalog) {
        let catalog = MockCatalog()
        catalog.teams = [bleus, devils, blacks]
        let sut = EditMatchViewModel(
            match: .stub(teamVisuals: visuals),
            updateUseCase: update,
            fetchFieldIdNamesUseCase: MockFields(),
            fetchTeamCatalogUseCase: catalog
        )
        sut.selectedField = .stub()
        return (sut, catalog)
    }

    private var snapshot: AdminMatchTeamVisuals {
        AdminMatchTeamVisuals(
            teamA: AdminMatchTeamVisual(name: "Les Bleus", colorHex: "#315DA8"),
            teamB: AdminMatchTeamVisual(name: "Red Devils", colorHex: "#B43C4A")
        )
    }

    func test_loadTeams_preselectsCatalogEntries_matchingTheMatchSnapshot() async {
        let (sut, _) = makeSUT(visuals: snapshot)

        await sut.loadTeams()

        XCTAssertEqual(sut.selectedTeamA?.id, "bleus")
        XCTAssertEqual(sut.selectedTeamB?.id, "devils")
        XCTAssertFalse(sut.hasChanges, "Resolving the snapshot must not read as an edit")
    }

    func test_teamBOptions_excludeTeamASelection() async {
        let (sut, _) = makeSUT(visuals: snapshot)
        await sut.loadTeams()

        XCTAssertFalse(sut.teamBOptions.contains { $0.id == sut.selectedTeamA?.id })
        XCTAssertEqual(sut.teamBOptions.count, 2)
    }

    func test_changingATeam_marksChanges_andSendsBothIds() async {
        let update = MockUpdate()
        let (sut, _) = makeSUT(visuals: snapshot, update: update)
        await sut.loadTeams()

        sut.selectedTeamB = blacks
        XCTAssertTrue(sut.hasChanges)
        await sut.save()

        XCTAssertEqual(update.receivedParams?.teamAId, "bleus")
        XCTAssertEqual(update.receivedParams?.teamBId, "blacks")
    }

    func test_untouchedTeams_areOmittedFromTheUpdate_soTheSnapshotIsKept() async {
        let update = MockUpdate()
        let (sut, _) = makeSUT(visuals: snapshot, update: update)
        await sut.loadTeams()
        sut.maxPlayersText = "12"   // an unrelated edit
        await sut.save()

        XCTAssertNil(update.receivedParams?.teamAId)
        XCTAssertNil(update.receivedParams?.teamBId)
    }

    func test_isInvalid_whenOnlyOneTeamIsSelected() async {
        let (sut, _) = makeSUT(visuals: nil)
        await sut.loadTeams()

        sut.selectedTeamA = bleus
        sut.selectedTeamB = nil

        XCTAssertFalse(sut.isValid)
    }

    func test_isInvalid_whenBothTeamsAreTheSame() async {
        let (sut, _) = makeSUT(visuals: nil)
        await sut.loadTeams()

        sut.selectedTeamA = bleus
        sut.selectedTeamB = bleus

        XCTAssertFalse(sut.isValid)
    }

    func test_legacyMatchWithoutSnapshot_isValidAndUnchanged_untilTeamsArePicked() async {
        let (sut, _) = makeSUT(visuals: nil)
        await sut.loadTeams()

        XCTAssertTrue(sut.isValid)
        XCTAssertFalse(sut.hasChanges)

        sut.selectedTeamA = bleus
        sut.selectedTeamB = devils
        XCTAssertTrue(sut.hasChanges)
    }
}
