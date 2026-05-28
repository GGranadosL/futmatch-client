import Foundation

// MARK: - PlayerStats

public struct PlayerStats: Equatable {
    public let matchesPlayed: Int
    public let matchesWon: Int
    public let mvpCount: Int
    public let totalGoals: Int

    public init(matchesPlayed: Int, matchesWon: Int, mvpCount: Int, totalGoals: Int) {
        self.matchesPlayed = matchesPlayed
        self.matchesWon = matchesWon
        self.mvpCount = mvpCount
        self.totalGoals = totalGoals
    }
}

// MARK: - User Entity

/// Domain entity representing the authenticated user
public struct User: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let lastName: String
    public let email: String
    public let phone: String
    public let status: UserStatus
    public let country: String
    public let birthDate: Date
    /// Nil when fetched from /profiles/me (which omits gender).
    public let gender: Gender?
    public let playerPosition: PlayerPosition
    public let profilePic: String
    public let level: PlayerLevel
    public let userRole: UserRole
    public let isEmailVerified: Bool
    /// Win-rate percentage 0–100. Populated by /profiles/me; nil when loaded from cache.
    public let averageScore: Int?
    /// Career stats. Populated by /profiles/me; nil when loaded from cache.
    public let stats: PlayerStats?

    public init(
        id: String,
        name: String,
        lastName: String,
        email: String = "",
        phone: String = "",
        status: UserStatus = .active,
        country: String,
        birthDate: Date = Date(),
        gender: Gender? = nil,
        playerPosition: PlayerPosition,
        profilePic: String = "",
        level: PlayerLevel,
        userRole: UserRole = .player,
        isEmailVerified: Bool = false,
        averageScore: Int? = nil,
        stats: PlayerStats? = nil
    ) {
        self.id = id
        self.name = name
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.status = status
        self.country = country
        self.birthDate = birthDate
        self.gender = gender
        self.playerPosition = playerPosition
        self.profilePic = profilePic
        self.level = level
        self.userRole = userRole
        self.isEmailVerified = isEmailVerified
        self.averageScore = averageScore
        self.stats = stats
    }

    /// Full display name
    public var fullName: String {
        "\(name) \(lastName)"
    }

    /// Profile picture as a URL (nil when empty or invalid).
    public var profilePicURL: URL? {
        guard !profilePic.isEmpty else { return nil }
        return URL(string: profilePic)
    }

    /// Flag emoji derived from ISO-2 country code (e.g. "MX" → "🇲🇽").
    public var countryFlag: String {
        let iso = country.uppercased()
        guard iso.count == 2, iso.unicodeScalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 }) else {
            return "🏳️"
        }
        return iso.unicodeScalars.map {
            String(Unicode.Scalar($0.value + 127397)!)
        }.joined()
    }

    /// Localized country name derived from ISO-2 code (e.g. "MX" → "México").
    public var countryDisplayName: String {
        Locale.current.localizedString(forRegionCode: country) ?? country
    }
}
