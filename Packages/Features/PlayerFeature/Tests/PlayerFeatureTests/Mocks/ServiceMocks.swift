import Foundation
import PersistenceFramework
@testable import PlayerFeature

// MARK: - MockMatchService

final class MockMatchService: MatchServiceProtocol {

    var fetchMatchesV2Result: Result<MatchesV2Result, Error> = .success(
        MatchesV2Result(region: "MX:CDMX", currentVersion: 1, hasChanges: true, matches: [])
    )
    private(set) var fetchMatchesV2CallCount = 0
    private(set) var lastSinceVersion: Int64?
    private(set) var lastV2CountryCode: String?
    private(set) var lastV2StateCode: String?
    private(set) var lastV2Lat: Double?
    private(set) var lastV2Lon: Double?
    func fetchMatchesV2(
        sinceVersion: Int64?,
        countryCode: String?,
        stateCode: String?,
        lat: Double?,
        lon: Double?
    ) async throws -> MatchesV2Result {
        fetchMatchesV2CallCount += 1
        lastSinceVersion = sinceVersion
        lastV2CountryCode = countryCode
        lastV2StateCode = stateCode
        lastV2Lat = lat
        lastV2Lon = lon
        return try fetchMatchesV2Result.get()
    }

    var fetchMatchesResult: Result<[MatchItem], Error> = .success([])
    private(set) var fetchMatchesCallCount = 0
    private(set) var lastFetchMatchesLat: Double?
    private(set) var lastFetchMatchesLon: Double?
    func fetchMatches(lat: Double?, lon: Double?) async throws -> [MatchItem] {
        fetchMatchesCallCount += 1
        lastFetchMatchesLat = lat
        lastFetchMatchesLon = lon
        return try fetchMatchesResult.get()
    }

    var fetchMyMatchesResult: Result<[MatchItem], Error> = .success([])
    private(set) var fetchMyMatchesCallCount = 0
    private(set) var lastMyMatchesLat: Double?
    private(set) var lastMyMatchesLon: Double?
    func fetchMyMatches(lat: Double?, lon: Double?) async throws -> [MatchItem] {
        fetchMyMatchesCallCount += 1
        lastMyMatchesLat = lat
        lastMyMatchesLon = lon
        return try fetchMyMatchesResult.get()
    }

    var fetchMatchDetailResult: Result<MatchItem, Error> = .success(.stub())
    private(set) var fetchMatchDetailCallCount = 0
    private(set) var lastDetailId: String?
    func fetchMatchDetail(id: String) async throws -> MatchItem {
        fetchMatchDetailCallCount += 1
        lastDetailId = id
        return try fetchMatchDetailResult.get()
    }

    var joinMatchResult: Result<JoinMatchData, Error> = .success(.stub())
    private(set) var joinMatchCallCount = 0
    private(set) var lastJoinId: String?
    private(set) var lastJoinTeam: String?
    func joinMatch(id: String, team: String?) async throws -> JoinMatchData {
        joinMatchCallCount += 1
        lastJoinId = id
        lastJoinTeam = team
        return try joinMatchResult.get()
    }

    var cancelMatchResult: Result<Void, Error> = .success(())
    private(set) var cancelMatchCallCount = 0
    private(set) var lastCancelId: String?
    func cancelMatch(id: String) async throws {
        cancelMatchCallCount += 1
        lastCancelId = id
        try cancelMatchResult.get()
    }

    var leaveMatchResult: Result<Void, Error> = .success(())
    private(set) var leaveMatchCallCount = 0
    private(set) var lastLeaveId: String?
    func leaveMatch(id: String) async throws {
        leaveMatchCallCount += 1
        lastLeaveId = id
        try leaveMatchResult.get()
    }
}

// MARK: - MockMatchVersionStore

/// In-memory `MatchVersionStoreProtocol` for testing the versioned fetch flow.
final class MockMatchVersionStore: MatchVersionStoreProtocol {
    var storage: [String: Int64] = [:]
    private(set) var clearCallCount = 0
    private(set) var lastSetRegion: String?

    func version(for region: String) -> Int64? {
        storage[region]
    }

    func setVersion(_ version: Int64, for region: String) {
        lastSetRegion = region
        storage[region] = version
    }

    func clear() {
        clearCallCount += 1
        storage.removeAll()
    }
}

// MARK: - MockPaymentService

final class MockPaymentService: PaymentServiceProtocol {

    var fetchCustomerSessionResult: Result<CustomerSessionData, Error> = .success(.stub())
    private(set) var fetchCustomerSessionCallCount = 0
    func fetchCustomerSession() async throws -> CustomerSessionData {
        fetchCustomerSessionCallCount += 1
        return try fetchCustomerSessionResult.get()
    }

    var createSetupIntentResult: Result<SetupIntentData, Error>?
    func createSetupIntent() async throws -> SetupIntentData {
        guard let createSetupIntentResult else { fatalError("createSetupIntent not stubbed") }
        return try createSetupIntentResult.get()
    }

    var fetchPaymentMethodsResult: Result<[PaymentMethodItem], Error> = .success([])
    func fetchPaymentMethods() async throws -> [PaymentMethodItem] {
        try fetchPaymentMethodsResult.get()
    }

    var fetchPaymentHistoryResult: Result<[PaymentHistoryItem], Error> = .success([])
    private(set) var fetchPaymentHistoryCallCount = 0
    func fetchPaymentHistory() async throws -> [PaymentHistoryItem] {
        fetchPaymentHistoryCallCount += 1
        return try fetchPaymentHistoryResult.get()
    }

    var pollPaymentStatusResult: Result<PaymentPollData?, Error> = .success(nil)
    private(set) var pollPaymentStatusCallCount = 0
    private(set) var lastPollMatchId: String?
    func pollPaymentStatus(matchId: String) async throws -> PaymentPollData? {
        pollPaymentStatusCallCount += 1
        lastPollMatchId = matchId
        return try pollPaymentStatusResult.get()
    }

    var fetchPaymentStatusResult: Result<PaymentStatusData?, Error> = .success(nil)
    private(set) var fetchPaymentStatusCallCount = 0
    private(set) var lastStatusMatchId: String?
    func fetchPaymentStatus(matchId: String) async throws -> PaymentStatusData? {
        fetchPaymentStatusCallCount += 1
        lastStatusMatchId = matchId
        return try fetchPaymentStatusResult.get()
    }
}

// MARK: - MockDeviceService

final class MockDeviceService: DeviceServiceProtocol {
    var updateFCMTokenResult: Result<Void, Error> = .success(())
    private(set) var updateFCMTokenCallCount = 0
    private(set) var lastRequest: UpdateFCMTokenRequest?
    func updateFCMToken(_ request: UpdateFCMTokenRequest) async throws {
        updateFCMTokenCallCount += 1
        lastRequest = request
        try updateFCMTokenResult.get()
    }
}

// MARK: - MockMatchPlayersListener

final class MockMatchPlayersListener: MatchPlayersListenerProtocol {
    var snapshotsToEmit: [MatchPlayersSnapshot] = []
    private(set) var lastMatchId: String?
    func playerStream(matchId: String) -> AsyncStream<MatchPlayersSnapshot> {
        lastMatchId = matchId
        let snapshots = snapshotsToEmit
        return AsyncStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
}

// MARK: - MockKeychain

/// In-memory `KeychainManaging` so use cases that read/write tokens can be tested
/// without touching the real Keychain.
final class MockKeychain: KeychainManaging {
    var storage: [KeychainKey: String] = [:]
    var saveError: Error?

    private(set) var savedPairs: [(KeychainKey, String)] = []

    func save(_ value: String, for key: KeychainKey) throws {
        if let saveError { throw saveError }
        storage[key] = value
        savedPairs.append((key, value))
    }

    func retrieve(for key: KeychainKey) throws -> String? {
        storage[key]
    }

    func delete(for key: KeychainKey) throws {
        storage[key] = nil
    }

    func saveAuthTokens(accessToken: String, refreshToken: String, userId: String, deviceId: String, firebaseToken: String?) throws {
        storage[.accessToken] = accessToken
        storage[.refreshToken] = refreshToken
        storage[.userId] = userId
        storage[.deviceId] = deviceId
        if let firebaseToken { storage[.firebaseToken] = firebaseToken }
    }

    func clearAuthData() throws {
        [.accessToken, .refreshToken, .userId, .firebaseToken, .fcmToken].forEach { storage[$0] = nil }
    }
}
