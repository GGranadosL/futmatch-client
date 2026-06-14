import Foundation

// MARK: - Protocol

public protocol FetchAdminDashboardUseCaseProtocol {
    func execute() async throws -> AdminDashboard
}

// MARK: - Implementation

public struct FetchAdminDashboardUseCase: FetchAdminDashboardUseCaseProtocol {
    private let repository: AdminDashboardRepositoryProtocol

    public init(repository: AdminDashboardRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> AdminDashboard {
        try await repository.fetchDashboard()
    }
}
