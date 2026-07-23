import Foundation
import CoreLocation

// MARK: - AdminMatch

public struct AdminMatch: Identifiable, Equatable {
    public let id: String           // matchId — also the Firestore lineup document id
    public let fieldName: String
    public let dateLabel: String    // "Hoy", "Mañana", "Lunes 10"
    public let timeRange: String    // "20:00 – 22:00"
    public let price: String        // "$12.00"
    public let gender: MatchGender
    public let playerLevel: MatchPlayerLevel
    public let spotsFilled: Int
    public let spotsTotal: Int
    public let status: AdminMatchStatus
    public let fieldImageUrl: String?
    public let startDate: Date

    // MARK: - Detail enrichment (used by AdminMatchDetailView)

    /// Owning field id — used to load field details/rules and (later) editing.
    public let fieldId: String
    public let endDate: Date
    /// Minimum players required for the match to proceed. 0 when not available (e.g. cached).
    public let minPlayers: Int
    public let address: String?
    /// Stored as primitives (not `CLLocationCoordinate2D`) so `Equatable` stays synthesized.
    public let latitude: Double?
    public let longitude: Double?

    public init(
        id: String,
        fieldName: String,
        dateLabel: String,
        timeRange: String,
        price: String,
        gender: MatchGender,
        playerLevel: MatchPlayerLevel,
        spotsFilled: Int,
        spotsTotal: Int,
        status: AdminMatchStatus,
        fieldImageUrl: String?,
        startDate: Date,
        fieldId: String = "",
        endDate: Date = Date(),
        minPlayers: Int = 0,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.fieldName = fieldName
        self.dateLabel = dateLabel
        self.timeRange = timeRange
        self.price = price
        self.gender = gender
        self.playerLevel = playerLevel
        self.spotsFilled = spotsFilled
        self.spotsTotal = spotsTotal
        self.status = status
        self.fieldImageUrl = fieldImageUrl
        self.startDate = startDate
        self.fieldId = fieldId
        self.endDate = endDate
        self.minPlayers = minPlayers
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }

    public var occupancyLabel: String { "\(spotsFilled)/\(spotsTotal)" }
    public var isIncomplete: Bool { spotsFilled < spotsTotal }

    /// Remaining open slots, clamped at 0.
    public var spotsLeft: Int { max(0, spotsTotal - spotsFilled) }

    /// Map coordinate when the field location supplied lat/lon.
    public var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Match length in whole minutes formatted like `"60 min"`.
    public var duration: String {
        let minutes = max(0, Int(endDate.timeIntervalSince(startDate) / 60))
        return "\(minutes) min"
    }
}

// MARK: - UpdateMatchParams

public struct UpdateMatchParams {
    public let matchId: String
    public let fieldId: String
    public let fieldName: String
    public let date: Date
    public let startTime: Date
    public let endTime: Date
    public let minPlayers: Int
    public let maxPlayers: Int
    public let priceInCents: Int
    public let gender: MatchGender
    public let playerLevel: MatchPlayerLevel

    public init(
        matchId: String,
        fieldId: String,
        fieldName: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        minPlayers: Int,
        maxPlayers: Int,
        priceInCents: Int,
        gender: MatchGender,
        playerLevel: MatchPlayerLevel
    ) {
        self.matchId = matchId
        self.fieldId = fieldId
        self.fieldName = fieldName
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.priceInCents = priceInCents
        self.gender = gender
        self.playerLevel = playerLevel
    }
}

// MARK: - CreateMatchParams

public struct CreateMatchParams {
    /// ID of the field where the match is played.
    public let fieldId: String
    /// Display name of the field — used locally to populate the domain model
    /// returned from `createMatch` (the create response omits `fieldName`).
    public let fieldName: String
    public let organizerId: String
    public let date: Date
    public let startTime: Date
    public let endTime: Date
    public let minPlayers: Int
    public let maxPlayers: Int
    public let priceInCents: Int
    public let gender: MatchGender
    public let playerLevel: MatchPlayerLevel

    public init(
        fieldId: String,
        fieldName: String,
        organizerId: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        minPlayers: Int,
        maxPlayers: Int,
        priceInCents: Int,
        gender: MatchGender,
        playerLevel: MatchPlayerLevel
    ) {
        self.fieldId = fieldId
        self.fieldName = fieldName
        self.organizerId = organizerId
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.priceInCents = priceInCents
        self.gender = gender
        self.playerLevel = playerLevel
    }
}
