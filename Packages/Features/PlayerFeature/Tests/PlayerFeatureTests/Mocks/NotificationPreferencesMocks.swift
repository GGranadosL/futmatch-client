import Foundation
@testable import PlayerFeature

struct StubError: Error {}

final class MockNotificationPreferencesRepository: NotificationPreferencesRepositoryProtocol {
    var stubbedEnabled = true
    var fetchError: Error?
    var setError: Error?
    private(set) var setValues: [Bool] = []

    func fetchMatchInvitesEnabled() async throws -> Bool {
        if let fetchError { throw fetchError }
        return stubbedEnabled
    }

    func setMatchInvitesEnabled(_ enabled: Bool) async throws {
        setValues.append(enabled)
        if let setError { throw setError }
    }
}

final class MockGetMatchInvitesEnabledUseCase: GetMatchInvitesEnabledUseCaseProtocol {
    var result: Result<Bool, Error> = .success(true)
    private(set) var callCount = 0

    func execute() async throws -> Bool {
        callCount += 1
        return try result.get()
    }
}

final class MockSetMatchInvitesEnabledUseCase: SetMatchInvitesEnabledUseCaseProtocol {
    var error: Error?
    private(set) var values: [Bool] = []

    func execute(_ enabled: Bool) async throws {
        values.append(enabled)
        if let error { throw error }
    }
}
