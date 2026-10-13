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

        return AdminDashboardComposer.compose(fieldsCount: fields.count, matches: matches, now: Date())
    }
}

/// Pure dashboard assembly, kept apart from the fetching so the status rules can be tested.
enum AdminDashboardComposer {
    /// Live and upcoming matches only show within this window of "now"; matches
    /// awaiting their result are always shown because the organizer must act on them.
    private static let nearWindow: TimeInterval = 3 * 3600

    static func compose(fieldsCount: Int, matches: [AdminMatch], now: Date) -> AdminDashboard {
        let active = matches.filter {
            $0.status == .scheduled || $0.status == .inProgress || $0.status == .pendingResult
        }
        let shown = active.filter {
            $0.status == .pendingResult || abs($0.startDate.timeIntervalSince(now)) <= nearWindow
        }

        let sorted = shown.sorted { a, b in
            if a.status.dashboardPriority != b.status.dashboardPriority {
                return a.status.dashboardPriority < b.status.dashboardPriority
            }
            return a.startDate < b.startDate
        }

        return AdminDashboard(
            scheduledMatchesCount: active.count,
            registeredVenuesCount: fieldsCount,
            upcomingMatches: sorted.map { $0.toUpcomingMatch() },
            ongoingFullMatches: sorted
        )
    }
}

private extension AdminMatchStatus {
    /// Live first, then matches waiting on a result, then the rest by start time.
    var dashboardPriority: Int {
        switch self {
        case .inProgress:    return 0
        case .pendingResult: return 1
        default:             return 2
        }
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
            fieldImageUrl: fieldImageUrl,
            status: status
        )
    }
}
