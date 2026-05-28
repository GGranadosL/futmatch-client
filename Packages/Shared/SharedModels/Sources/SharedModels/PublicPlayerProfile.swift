import Foundation

// MARK: - PlayerLastMatch

public struct PlayerLastMatch: Equatable {
    public let matchId: String
    public let fieldId: String
    public let fieldName: String
    public let playedAt: Date
    public let outcome: String
    public let teamAScore: Int
    public let teamBScore: Int

    public init(
        matchId: String,
        fieldId: String,
        fieldName: String,
        playedAt: Date,
        outcome: String,
        teamAScore: Int,
        teamBScore: Int
    ) {
        self.matchId = matchId
        self.fieldId = fieldId
        self.fieldName = fieldName
        self.playedAt = playedAt
        self.outcome = outcome
        self.teamAScore = teamAScore
        self.teamBScore = teamBScore
    }
}

// MARK: - PublicPlayerProfile

public struct PublicPlayerProfile: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let lastName: String
    public let country: String
    public let playerPosition: PlayerPosition
    public let profilePic: String?
    public let level: PlayerLevel
    public let averageScore: Int
    public let stats: PlayerStats
    public let lastMatch: PlayerLastMatch?

    public init(
        id: String,
        name: String,
        lastName: String,
        country: String,
        playerPosition: PlayerPosition,
        profilePic: String?,
        level: PlayerLevel,
        averageScore: Int,
        stats: PlayerStats,
        lastMatch: PlayerLastMatch?
    ) {
        self.id = id
        self.name = name
        self.lastName = lastName
        self.country = country
        self.playerPosition = playerPosition
        self.profilePic = profilePic
        self.level = level
        self.averageScore = averageScore
        self.stats = stats
        self.lastMatch = lastMatch
    }

    public var fullName: String { "\(name) \(lastName)" }

    public var profilePicURL: URL? {
        guard let pic = profilePic, !pic.isEmpty else { return nil }
        return URL(string: pic)
    }
}
