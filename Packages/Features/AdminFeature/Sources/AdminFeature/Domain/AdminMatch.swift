import Foundation

// MARK: - AdminMatch

public struct AdminMatch: Identifiable, Equatable {
    public let id: String
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

    public var occupancyLabel: String { "\(spotsFilled)/\(spotsTotal)" }
    public var isIncomplete: Bool { spotsFilled < spotsTotal }
}

// MARK: - CreateMatchParams

public struct CreateMatchParams {
    /// ID of the field where the match is played.
    public let fieldId: String
    /// Display name of the field — used locally to populate the domain model
    /// returned from `createMatch` (the create response omits `fieldName`).
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
