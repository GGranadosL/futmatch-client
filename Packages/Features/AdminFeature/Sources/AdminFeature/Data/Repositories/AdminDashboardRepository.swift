import Foundation

/// API-backed `AdminDashboardRepositoryProtocol`.
///
/// - `registeredVenuesCount` → real count from `GET /fields/by-admin`.
/// - `scheduledMatchesCount` and `upcomingMatches` → placeholders (0 / empty)
///   until the corresponding backend endpoints exist.
struct AdminDashboardRepository: AdminDashboardRepositoryProtocol {
    private let fieldService: FieldServiceProtocol

    init(fieldService: FieldServiceProtocol) {
        self.fieldService = fieldService
    }

    func fetchDashboard() async throws -> AdminDashboard {
        let fields = try await fieldService.fetchFieldsByAdmin()
        return AdminDashboard(
            scheduledMatchesCount: 0,       // TODO: wire real endpoint when available
            registeredVenuesCount: fields.count,
            upcomingMatches: []             // TODO: wire real endpoint when available
        )
    }
}
