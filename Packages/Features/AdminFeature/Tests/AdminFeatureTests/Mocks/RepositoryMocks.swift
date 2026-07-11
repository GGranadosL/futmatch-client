import Foundation
@testable import AdminFeature

// MARK: - MockFieldRepository

/// Records calls and lets each method be stubbed with a success value or an error,
/// so the FieldRepository-backed use cases can be tested in isolation.
final class MockFieldRepository: FieldRepositoryProtocol {

    // createField
    var createFieldResult: Result<Field, Error> = .success(.stub())
    private(set) var createFieldCallCount = 0
    private(set) var lastCreateParams: CreateFieldParams?
    func createField(_ params: CreateFieldParams) async throws -> Field {
        createFieldCallCount += 1
        lastCreateParams = params
        return try createFieldResult.get()
    }

    // updateField
    var updateFieldResult: Result<Void, Error> = .success(())
    private(set) var updateFieldCallCount = 0
    private(set) var lastUpdateFieldId: String?
    private(set) var lastUpdateParams: CreateFieldParams?
    func updateField(fieldId: String, _ params: CreateFieldParams) async throws {
        updateFieldCallCount += 1
        lastUpdateFieldId = fieldId
        lastUpdateParams = params
        try updateFieldResult.get()
    }

    // deleteField
    var deleteFieldResult: Result<Void, Error> = .success(())
    private(set) var deleteFieldCallCount = 0
    private(set) var lastDeleteFieldId: String?
    func deleteField(fieldId: String) async throws {
        deleteFieldCallCount += 1
        lastDeleteFieldId = fieldId
        try deleteFieldResult.get()
    }

    // linkLocation
    var linkLocationResult: Result<Void, Error> = .success(())
    private(set) var linkLocationCallCount = 0
    private(set) var lastLinkFieldId: String?
    private(set) var lastLinkLocationId: String?
    func linkLocation(fieldId: String, locationId: String) async throws {
        linkLocationCallCount += 1
        lastLinkFieldId = fieldId
        lastLinkLocationId = locationId
        try linkLocationResult.get()
    }

    // fetchFieldIdNames
    var fetchFieldIdNamesResult: Result<[FieldIdName], Error> = .success([])
    private(set) var fetchFieldIdNamesCallCount = 0
    func fetchFieldIdNames() async throws -> [FieldIdName] {
        fetchFieldIdNamesCallCount += 1
        return try fetchFieldIdNamesResult.get()
    }

    // uploadFieldImage
    var uploadFieldImageResult: Result<String, Error> = .success("uploaded-id")
    private(set) var uploadFieldImageCallCount = 0
    private(set) var lastUploadFieldId: String?
    private(set) var lastUploadPosition: Int?
    private(set) var lastUploadData: Data?
    func uploadFieldImage(fieldId: String, position: Int, imageData: Data) async throws -> String {
        uploadFieldImageCallCount += 1
        lastUploadFieldId = fieldId
        lastUploadPosition = position
        lastUploadData = imageData
        return try uploadFieldImageResult.get()
    }

    // replaceFieldImage
    var replaceFieldImageResult: Result<String, Error> = .success("replaced-id")
    private(set) var replaceFieldImageCallCount = 0
    private(set) var lastReplaceFieldId: String?
    private(set) var lastReplaceImageId: String?
    private(set) var lastReplaceData: Data?
    func replaceFieldImage(fieldId: String, imageId: String, imageData: Data) async throws -> String {
        replaceFieldImageCallCount += 1
        lastReplaceFieldId = fieldId
        lastReplaceImageId = imageId
        lastReplaceData = imageData
        return try replaceFieldImageResult.get()
    }

    // deleteFieldImage
    var deleteFieldImageResult: Result<Void, Error> = .success(())
    private(set) var deleteFieldImageCallCount = 0
    private(set) var lastDeleteImageFieldId: String?
    private(set) var lastDeleteImageId: String?
    func deleteFieldImage(fieldId: String, imageId: String) async throws {
        deleteFieldImageCallCount += 1
        lastDeleteImageFieldId = fieldId
        lastDeleteImageId = imageId
        try deleteFieldImageResult.get()
    }

    // downloadFieldImage
    var downloadFieldImageResult: Result<Data, Error> = .success(Data())
    private(set) var downloadFieldImageCallCount = 0
    private(set) var lastDownloadImageName: String?
    func downloadFieldImage(imageName: String) async throws -> Data {
        downloadFieldImageCallCount += 1
        lastDownloadImageName = imageName
        return try downloadFieldImageResult.get()
    }
}

// MARK: - MockAdminFieldsRepository

final class MockAdminFieldsRepository: AdminFieldsRepositoryProtocol {
    var fetchFieldsResult: Result<[AdminFieldItem], Error> = .success([])
    private(set) var fetchFieldsCallCount = 0
    func fetchFields() async throws -> [AdminFieldItem] {
        fetchFieldsCallCount += 1
        return try fetchFieldsResult.get()
    }
}

// MARK: - MockAdminMatchRepository

final class MockAdminMatchRepository: AdminMatchRepositoryProtocol {
    var fetchMatchesResult: Result<[AdminMatch], Error> = .success([])
    func fetchMatches() async throws -> [AdminMatch] { try fetchMatchesResult.get() }

    var createMatchResult: Result<AdminMatch, Error> = .success(.stub())
    func createMatch(_ params: CreateMatchParams) async throws -> AdminMatch { try createMatchResult.get() }

    var updateMatchResult: Result<AdminMatch, Error> = .success(.stub())
    func updateMatch(_ params: UpdateMatchParams) async throws -> AdminMatch { try updateMatchResult.get() }

    var cancelMatchResult: Result<Void, Error> = .success(())
    private(set) var cancelMatchCallCount = 0
    private(set) var lastCancelMatchId: String?
    private(set) var lastCancelReason: String?
    func cancelMatch(matchId: String, reason: String) async throws {
        cancelMatchCallCount += 1
        lastCancelMatchId = matchId
        lastCancelReason = reason
        try cancelMatchResult.get()
    }

    var completeMatchResult: Result<Void, Error> = .success(())
    func completeMatch(params: CompleteMatchParams) async throws { try completeMatchResult.get() }

    var fetchMatchPlayersResult: Result<(teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer]), Error> = .success(([], []))
    private(set) var fetchMatchPlayersCallCount = 0
    private(set) var lastFetchMatchPlayersId: String?
    func fetchMatchPlayers(matchId: String) async throws -> (teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer]) {
        fetchMatchPlayersCallCount += 1
        lastFetchMatchPlayersId = matchId
        return try fetchMatchPlayersResult.get()
    }

    var rebalanceTeamsResult: Result<Void, Error> = .success(())
    func rebalanceTeams(matchId: String, assignments: [(userId: String, team: String)]) async throws {
        try rebalanceTeamsResult.get()
    }
}

// MARK: - MockFetchAdminMatchPlayersUseCase

final class MockFetchAdminMatchPlayersUseCase: FetchAdminMatchPlayersUseCaseProtocol {
    var result: Result<(teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer]), Error> = .success(([], []))
    private(set) var callCount = 0
    private(set) var lastMatchId: String?
    func execute(matchId: String) async throws -> (teamA: [AdminMatchPlayer], teamB: [AdminMatchPlayer]) {
        callCount += 1
        lastMatchId = matchId
        return try result.get()
    }
}

// MARK: - MockSubscribeAdminMatchPlayersUseCase

final class MockSubscribeAdminMatchPlayersUseCase: SubscribeAdminMatchPlayersUseCaseProtocol {
    var snapshotsToEmit: [AdminMatchPlayersSnapshot] = []
    private(set) var callCount = 0
    func execute(matchId: String) -> AsyncThrowingStream<AdminMatchPlayersSnapshot, Error> {
        callCount += 1
        let snapshots = snapshotsToEmit
        return AsyncThrowingStream { continuation in
            for s in snapshots { continuation.yield(s) }
            continuation.finish()
        }
    }
}

// MARK: - MockCancelAdminMatchUseCase

final class MockCancelAdminMatchUseCase: CancelAdminMatchUseCaseProtocol {
    var result: Result<Void, Error> = .success(())
    private(set) var callCount = 0
    private(set) var lastMatchId: String?
    private(set) var lastReason: String?
    func execute(matchId: String, reason: String) async throws {
        callCount += 1
        lastMatchId = matchId
        lastReason = reason
        try result.get()
    }
}

// MARK: - MockFetchAdminFieldsUseCase

final class MockFetchAdminFieldsUseCase: FetchAdminFieldsUseCaseProtocol {
    var result: Result<[AdminFieldItem], Error> = .success([])
    public func execute() async throws -> [AdminFieldItem] { try result.get() }
}

// MARK: - MockRebalanceTeamsUseCase

final class MockRebalanceTeamsUseCase: RebalanceTeamsUseCaseProtocol {
    var result: Result<Void, Error> = .success(())
    func execute(matchId: String, assignments: [(userId: String, team: String)]) async throws { try result.get() }
}

// MARK: - MockAdminDashboardRepository

final class MockAdminDashboardRepository: AdminDashboardRepositoryProtocol {
    var fetchDashboardResult: Result<AdminDashboard, Error> = .success(.stub())
    private(set) var fetchDashboardCallCount = 0
    func fetchDashboard() async throws -> AdminDashboard {
        fetchDashboardCallCount += 1
        return try fetchDashboardResult.get()
    }
}
