import Foundation

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
    public let gender: Gender
    public let playerPosition: PlayerPosition
    public let profilePic: String
    public let level: PlayerLevel
    public let userRole: UserRole
    public let isEmailVerified: Bool
    
    public init(
        id: String,
        name: String,
        lastName: String,
        email: String,
        phone: String,
        status: UserStatus,
        country: String,
        birthDate: Date,
        gender: Gender,
        playerPosition: PlayerPosition,
        profilePic: String,
        level: PlayerLevel,
        userRole: UserRole,
        isEmailVerified: Bool
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
    
    /// Country flag emoji
    public var countryFlag: String {
        switch country.lowercased() {
        case "méxico", "mexico": return "🇲🇽"
        case "usa", "estados unidos": return "🇺🇸"
        case "canadá", "canada": return "🇨🇦"
        case "argentina": return "🇦🇷"
        case "brasil", "brazil": return "🇧🇷"
        case "chile": return "🇨🇱"
        case "colombia": return "🇨🇴"
        case "españa", "spain": return "🇪🇸"
        case "francia", "france": return "🇫🇷"
        default: return "🏳️"
        }
    }
}
