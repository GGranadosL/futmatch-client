import Foundation

/// Turns automatic `MATCH_INVITE` pushes on or off for the user.
public protocol SetMatchInvitesEnabledUseCaseProtocol {
    func execute(_ enabled: Bool) async throws
}

public struct SetMatchInvitesEnabledUseCase: SetMatchInvitesEnabledUseCaseProtocol {
    private let repository: NotificationPreferencesRepositoryProtocol

    public init(repository: NotificationPreferencesRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(_ enabled: Bool) async throws {
        try await repository.setMatchInvitesEnabled(enabled)
    }
}
