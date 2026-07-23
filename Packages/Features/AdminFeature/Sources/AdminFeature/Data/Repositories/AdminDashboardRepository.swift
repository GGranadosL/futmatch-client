import Foundation

/// API-backed `AdminDashboardRepositoryProtocol`.
struct AdminDashboardRepository: AdminDashboardRepositoryProtocol {
    private let fieldService: FieldServiceProtocol
    private let matchRepository: AdminMatchRepositoryProtocol

    init(fieldService: FieldServiceProtocol, matchRepository: AdminMatchRepositoryProtocol) {
        self.fieldService = fieldService
        self.matchRepository = matchRepository
    }

    func fetchDashboard() async throws -> AdminDashboard {
        async let fieldsFetch = fieldService.fetchFieldsByAdmin()
        async let matchesFetch = matchRepository.fetchMatches()
        let (fields, matches) = try await (fieldsFetch, matchesFetch)

        let now = Date()
        let threeHours: TimeInterval = 3 * 3600

        let activeMatches = matches.filter { $0.status == .scheduled || $0.status == .inProgress }
        let ongoingMatches = activeMatches.filter { abs($0.startDate.timeIntervalSince(now)) <= threeHours }

        let sorted = ongoingMatches.sorted { a, b in
            if a.status == .inProgress && b.status != .inProgress { return true }
            if a.status != .inProgress && b.status == .inProgress { return false }
            return a.startDate < b.startDate
        }

        return AdminDashboard(
            scheduledMatchesCount: activeMatches.count,
            registeredVenuesCount: fields.count,
            upcomingMatches: sorted.map { $0.toUpcomingMatch() },
            ongoingFullMatches: sorted
        )
    }
}

private extension AdminMatch {
    func toUpcomingMatch() -> AdminUpcomingMatch {
        let startTime = timeRange.components(separatedBy: " – ").first ?? timeRange
        return AdminUpcomingMatch(
            id: id,
            venueName: fieldName,
            dateLabel: dateLabel,
            time: startTime,
            price: price,
            matchType: gender.displayName,
            spotsFilled: spotsFilled,
            spotsTotal: spotsTotal,
            fieldImageUrl: fieldImageUrl
        )
    }
}
