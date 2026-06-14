import Foundation

// MARK: - Gender

public enum Gender: String, Codable, Equatable, CaseIterable {
    case male = "MALE"
    case female = "FEMALE"
    case other = "OTHER"

    public var displayName: String {
        switch self {
        case .male: return "Masculino"
        case .female: return "Femenino"
        case .other: return "Otro"
        }
    }

    /// Asset name for the default avatar when the user has no profile picture.
    /// `.other` intentionally maps to the male asset (product decision).
    public var defaultAvatarAssetName: String {
        switch self {
        case .male, .other: return "defaultAvatar"
        case .female: return "defaultAvatarWoman"
        }
    }
}

// MARK: - Player Position

public enum PlayerPosition: String, Codable, Equatable, CaseIterable {
    case goalkeeper = "GOALKEEPER"
    case defender = "DEFENDER"
    case midfielder = "MIDFIELDER"
    case forward = "FORWARD"
    
    public var displayName: String {
        switch self {
        case .goalkeeper: return "Portero"
        case .defender: return "Defensa"
        case .midfielder: return "Mediocampista"
        case .forward: return "Delantero"
        }
    }
}

// MARK: - Player Level

public enum PlayerLevel: String, Codable, Equatable {
    case beginner = "BEGINNER"
    case amateur = "AMATEUR"
    case intermediate = "INTERMEDIATE"
    case advanced = "ADVANCED"
    case professional = "PROFESSIONAL"
    
    public var displayName: String {
        switch self {
        case .beginner: return "Principiante"
        case .amateur: return "Amateur"
        case .intermediate: return "Intermedio"
        case .advanced: return "Avanzado"
        case .professional: return "Profesional"
        }
    }
}

// MARK: - User Role

public enum UserRole: String, Codable, Equatable {
    case player = "PLAYER"
    case organizer = "ORGANIZER"
    case administrator = "ADMIN"
}

// MARK: - User Status

public enum UserStatus: String, Codable, Equatable {
    case active = "ACTIVE"
    case inactive = "INACTIVE"
    case suspended = "SUSPENDED"
}
