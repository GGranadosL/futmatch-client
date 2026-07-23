import Foundation

/// Abstracts organizer/supervisor-related data operations.
public protocol OrganizerRepositoryProtocol {
    func fetchOrganizers() async throws -> [Organizer]
}
