import Foundation

// MARK: - MatchGender

/// Gender restriction for a match. Raw values are sent verbatim to the backend.
/// Both `MALE`/`FEMALE` (current API contract) and `MALE_ONLY`/`FEMALE_ONLY`
/// are handled on the receive side via `genderFromBackend(_:)`.
public enum MatchGender: String, Codable, CaseIterable, Identifiable, Hashable, CustomStringConvertible {
    case mixed      = "MIXED"
    case maleOnly   = "MALE_ONLY"
    case femaleOnly = "FEMALE_ONLY"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mixed:      return L10n.MatchGender.mixed
        case .maleOnly:   return L10n.MatchGender.maleOnly
        case .femaleOnly: return L10n.MatchGender.femaleOnly
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
        case .beginner:     return L10n.MatchPlayerLevel.beginner
        case .intermediate: return L10n.MatchPlayerLevel.intermediate
        case .advanced:     return L10n.MatchPlayerLevel.advanced
        case .any:          return L10n.MatchPlayerLevel.any
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

    /// The backend emits both spellings for cancellation ("CANCELED"/"CANCELLED"),
    /// so raw-value decoding alone would misfile those matches under `.scheduled`.
    public init(backend value: String) {
        switch value.uppercased() {
        case "IN_PROGRESS": self = .inProgress
        case "COMPLETED":   self = .completed
        case "CANCELED",
             "CANCELLED":   self = .canceled
        default:            self = .scheduled
        }
    }

    public var displayName: String {
        switch self {
        case .scheduled:  return L10n.AdminMatchStatus.scheduled
        case .inProgress: return L10n.AdminMatchStatus.inProgress
        case .completed:  return L10n.AdminMatchStatus.completed
        case .canceled:   return L10n.AdminMatchStatus.canceled
        }
    }
}
