import Foundation

/// Concrete `OrganizerRepositoryProtocol` backed by the API via `UserService`.
struct OrganizerRepository: OrganizerRepositoryProtocol {
    private let service: UserServiceProtocol

    init(service: UserServiceProtocol) {
        self.service = service
    }

    func fetchOrganizers() async throws -> [Organizer] {
        try await service.fetchOrganizers()
    }
}
