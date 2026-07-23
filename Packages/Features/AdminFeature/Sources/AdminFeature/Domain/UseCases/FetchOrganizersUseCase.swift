import Foundation

public protocol FetchOrganizersUseCaseProtocol {
    func execute() async throws -> [Organizer]
}

public struct FetchOrganizersUseCase: FetchOrganizersUseCaseProtocol {
    private let repository: OrganizerRepositoryProtocol

    public init(repository: OrganizerRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [Organizer] {
        try await repository.fetchOrganizers()
    }
}
