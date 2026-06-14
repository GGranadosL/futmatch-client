import Foundation

// MARK: - FieldType

/// Surface/type of a field. Raw values match the backend `fieldType` contract.
public enum FieldType: String, Codable, Equatable, CaseIterable, CustomStringConvertible {
    case naturalGrass = "NATURAL_GRASS"
    case artificialTurf = "ARTIFICIAL_TURF"
    case indoor = "INDOOR"
    case futsal = "FUTSAL"

    public var displayName: String {
        switch self {
        case .naturalGrass:   return "Pasto natural"
        case .artificialTurf: return "Pasto sintético"
        case .indoor:         return "Cancha indoor"
        case .futsal:         return "Futsal"
        }
    }

    public var description: String { displayName }
}

// MARK: - FootwearType

/// Recommended footwear for a field. Raw values match the backend
/// `footwearType` contract.
public enum FootwearType: String, Codable, Equatable, CaseIterable, CustomStringConvertible {
    case indoor = "INDOOR"
    case turf = "TURF"
    case firmGround = "FIRM_GROUND"
    case artificialGrass = "ARTIFICIAL_GRASS"

    public var displayName: String {
        switch self {
        case .indoor:          return "Indoor"
        case .turf:            return "Turf"
        case .firmGround:      return "Natural"
        case .artificialGrass: return "Pasto artificial"
        }
    }

    public var description: String { displayName }
}
