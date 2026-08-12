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
        case .artificialTurf: return "Pasto artificial"
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
    case rubber = "RUBBER"

    public var displayName: String {
        switch self {
        case .indoor:          return "Indoor"
        case .turf:            return "Turf"
        case .firmGround:      return "Natural"
        case .artificialGrass: return "Pasto artificial"
        case .rubber:          return "Caucho"
        }
    }

    public var description: String { displayName }
}

// MARK: - FieldAttributeDisplay

/// Best-effort display name for a field/footwear type raw code that may not
/// be covered by `FieldType`/`FootwearType` (e.g. a value added only via
/// Remote Config, shown here before the enum ships a matching case). Falls
/// back to a humanized version of the raw code so nothing ever shows blank
/// or as a raw backend constant.
public enum FieldAttributeDisplay {
    public static func fieldTypeName(forCode code: String) -> String {
        FieldType(rawValue: code)?.displayName ?? humanize(code)
    }

    public static func footwearTypeName(forCode code: String) -> String {
        FootwearType(rawValue: code)?.displayName ?? humanize(code)
    }

    private static func humanize(_ raw: String) -> String {
        raw.lowercased().replacingOccurrences(of: "_", with: " ").capitalized
    }
}
