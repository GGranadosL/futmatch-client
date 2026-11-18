import Foundation

/// Concrete `NotificationPreferencesRepositoryProtocol` backed by the API.
struct NotificationPreferencesRepository: NotificationPreferencesRepositoryProtocol {
    private let service: NotificationPreferencesServiceProtocol

    init(service: NotificationPreferencesServiceProtocol) {
        self.service = service
    }

    func fetchMatchInvitesEnabled() async throws -> Bool {
        try await service.fetchMatchInvitesEnabled()
    }

    func setMatchInvitesEnabled(_ enabled: Bool) async throws {
        try await service.updateMatchInvitesEnabled(enabled)
    }
}
