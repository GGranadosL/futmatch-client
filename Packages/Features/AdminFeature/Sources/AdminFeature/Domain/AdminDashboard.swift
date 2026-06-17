import Foundation

// MARK: - AdminUpcomingMatch

/// A match shown in the admin home "Próximos Partidos" list.
public struct AdminUpcomingMatch: Identifiable, Equatable {
    public let id: String
    public let venueName: String
    /// Human label for the date, e.g. "Hoy".
    public let dateLabel: String
    /// Start time, e.g. "20:00".
    public let time: String
    /// Pre-formatted price, e.g. "$15.000".
    public let price: String
    /// Match type label, e.g. "Mixto".
    public let matchType: String
    public let spotsFilled: Int
    public let spotsTotal: Int
    /// Remote field image URL (nil → bundled default field image).
    public let fieldImageUrl: String?

    public init(
        id: String,
        venueName: String,
        dateLabel: String,
        time: String,
        price: String,
        matchType: String,
        spotsFilled: Int,
        spotsTotal: Int,
        fieldImageUrl: String? = nil
    ) {
        self.id = id
        self.venueName = venueName
        self.dateLabel = dateLabel
        self.time = time
        self.price = price
        self.matchType = matchType
        self.spotsFilled = spotsFilled
        self.spotsTotal = spotsTotal
        self.fieldImageUrl = fieldImageUrl
    }

    /// "8/14"
    public var occupancyLabel: String { "\(spotsFilled)/\(spotsTotal)" }

    /// True while the match still has open spots.
    public var isIncomplete: Bool { spotsFilled < spotsTotal }
}

// MARK: - AdminDashboard

/// Aggregated data backing the admin home screen.
public struct AdminDashboard: Equatable {
    public let scheduledMatchesCount: Int
    public let registeredVenuesCount: Int
    public let upcomingMatches: [AdminUpcomingMatch]

    public init(
        scheduledMatchesCount: Int,
        registeredVenuesCount: Int,
        upcomingMatches: [AdminUpcomingMatch]
    ) {
        self.scheduledMatchesCount = scheduledMatchesCount
        self.registeredVenuesCount = registeredVenuesCount
        self.upcomingMatches = upcomingMatches
    }
}
