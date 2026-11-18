import Foundation

/// Server-side notification preferences of the signed-in user.
public protocol NotificationPreferencesRepositoryProtocol {
    func fetchMatchInvitesEnabled() async throws -> Bool
    func setMatchInvitesEnabled(_ enabled: Bool) async throws
}
