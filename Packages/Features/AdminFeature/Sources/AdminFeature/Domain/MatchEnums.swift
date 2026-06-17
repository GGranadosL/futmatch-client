import Foundation

// MARK: - MatchGender

/// Gender restriction for a match. Raw values are sent verbatim to the backend.
/// Both `MALE`/`FEMALE` (current API contract) and `MALE_ONLY`/`FEMALE_ONLY`
/// are handled on the receive side via `genderFromBackend(_:)`.
public enum MatchGender: String, Codable, CaseIterable, Identifiable, Hashable, CustomStringConvertible {
    case mixed      = "MIXED"
    case maleOnly   = "MALE"
    case femaleOnly = "FEMALE"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mixed:      return "Mixto"
        case .maleOnly:   return "Solo hombres"
        case .femaleOnly: return "Solo mujeres"
        }
    }

    public var description: String { displayName }
}

/// Tolerates both `MALE`/`MALE_ONLY` and `FEMALE`/`FEMALE_ONLY` from the backend.
func genderFromBackend(_ raw: String) -> MatchGender {
    switch raw {
    case "MIXED":                return .mixed
    case "MALE", "MALE_ONLY":   return .maleOnly
    case "FEMALE", "FEMALE_ONLY": return .femaleOnly
    default:                     return .mixed
    }
}

// MARK: - MatchPlayerLevel

/// Required skill level for a match. Raw values match the backend `PlayerLevel` contract.
public enum MatchPlayerLevel: String, Codable, CaseIterable, Identifiable, Hashable, CustomStringConvertible {
    case beginner     = "BEGINNER"
    case intermediate = "INTERMEDIATE"
    case advanced     = "ADVANCED"
    case any          = "ANY"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .beginner:     return "Principiante"
        case .intermediate: return "Intermedio"
        case .advanced:     return "Avanzado"
        case .any:          return "Cualquier nivel"
        }
    }

    public var description: String { displayName }
}

// MARK: - AdminMatchStatus

/// Lifecycle state of a match as returned by the admin API.
public enum AdminMatchStatus: String, Equatable {
    case scheduled  = "SCHEDULED"
    case inProgress = "IN_PROGRESS"
    case completed  = "COMPLETED"
    case canceled   = "CANCELED"

    public var displayName: String {
        switch self {
        case .scheduled:  return "Programado"
        case .inProgress: return "En curso"
        case .completed:  return "Finalizado"
        case .canceled:   return "Cancelado"
        }
    }
}
