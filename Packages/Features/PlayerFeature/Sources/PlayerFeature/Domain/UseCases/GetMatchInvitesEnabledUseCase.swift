import Foundation

/// Whether the user receives automatic `MATCH_INVITE` pushes.
public protocol GetMatchInvitesEnabledUseCaseProtocol {
    func execute() async throws -> Bool
}

public struct GetMatchInvitesEnabledUseCase: GetMatchInvitesEnabledUseCaseProtocol {
    private let repository: NotificationPreferencesRepositoryProtocol

    public init(repository: NotificationPreferencesRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> Bool {
        try await repository.fetchMatchInvitesEnabled()
    }
}
