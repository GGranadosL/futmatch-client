import Foundation

/// Placeholder repository that returns representative admin data so the home
/// screen can be built and reviewed before the backend admin endpoints exist.
///
/// Swap this for an API-backed `AdminDashboardRepository` in
/// `AdminDependencyFactory.makeAdminDashboardRepository()` once the endpoints
/// are available — nothing else needs to change.
struct PreviewAdminDashboardRepository: AdminDashboardRepositoryProtocol {
    func fetchDashboard() async throws -> AdminDashboard {
        AdminDashboard(
            scheduledMatchesCount: 12,
            registeredVenuesCount: 8,
            upcomingMatches: [
                AdminUpcomingMatch(
                    id: "preview-1",
                    venueName: "Roma 29",
                    dateLabel: "Hoy",
                    time: "20:00",
                    price: "$15.000",
                    matchType: "Mixto",
                    spotsFilled: 8,
                    spotsTotal: 14
                )
            ]
        )
    }
}
