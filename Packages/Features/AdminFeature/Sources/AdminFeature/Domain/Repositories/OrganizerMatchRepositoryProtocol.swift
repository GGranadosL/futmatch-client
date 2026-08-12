import Foundation

/// Read-only match access for the `ORGANIZER` role. Organizers supervise matches
/// but never create them, so this protocol has no write operations —
/// see `AdminMatchRepositoryProtocol` for the admin-scoped counterpart.
protocol OrganizerMatchRepositoryProtocol {
    func fetchMatches() async throws -> [AdminMatch]
}
