import Foundation

/// Abstracts the data source backing the admin home dashboard.
public protocol AdminDashboardRepositoryProtocol {
    func fetchDashboard() async throws -> AdminDashboard
}
