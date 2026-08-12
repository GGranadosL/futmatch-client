import Foundation
import AdminFeature

/// Resolves a field-type/footwear-type raw backend code into a display
/// string for the match detail screen.
///
/// Looks up the live Remote Config catalog first (shared with AdminFeature's
/// field forms via `FieldAttributeCatalogRepositoryProtocol`, so both admin
/// and player always agree on the same values), then falls back to the
/// static switch this app has always used, then to a humanized raw code —
/// so a brand-new backend value never renders blank.
struct FieldAttributeCatalog: Equatable {
    private let fieldTypeNames: [String: String]
    private let footwearNames: [String: String]

    /// Empty catalog — behaves exactly like the static switch alone.
    init() {
        fieldTypeNames = [:]
        footwearNames = [:]
    }

    init(catalogs: FieldAttributeCatalogs) {
        let isSpanish = Locale.current.languageCode?.hasPrefix("es") ?? false
        fieldTypeNames = Dictionary(
            uniqueKeysWithValues: catalogs.fieldTypes.map { ($0.code, isSpanish ? $0.nameEs : $0.nameEn) }
        )
        footwearNames = Dictionary(
            uniqueKeysWithValues: catalogs.footwearTypes.map { ($0.code, isSpanish ? $0.nameEs : $0.nameEn) }
        )
    }

    func fieldTypeName(for code: String?) -> String {
        guard let code, !code.isEmpty else { return "" }
        let key = code.uppercased()
        if let name = fieldTypeNames[key] { return name }
        switch key {
        case "ARTIFICIAL_TURF", "SYNTHETIC": return L10n.MatchDetail.FieldTypeValue.artificialTurf
        case "NATURAL_GRASS", "NATURAL":     return L10n.MatchDetail.FieldTypeValue.naturalGrass
        case "INDOOR":                       return L10n.MatchDetail.FieldTypeValue.indoor
        case "FUTSAL":                       return L10n.MatchDetail.FieldTypeValue.futsal
        default:                             return MatchFormatters.humanize(code)
        }
    }

    func footwearName(for code: String?) -> String {
        guard let code, !code.isEmpty else { return "" }
        let key = code.uppercased()
        if let name = footwearNames[key] { return name }
        switch key {
        case "TURF":              return L10n.MatchDetail.FootwearValue.turf
        case "FIRM_GROUND":       return L10n.MatchDetail.FootwearValue.firmGround
        case "ARTIFICIAL_GRASS":  return L10n.MatchDetail.FootwearValue.artificialGrass
        case "INDOOR":            return L10n.MatchDetail.FootwearValue.indoor
        case "RUBBER":            return L10n.MatchDetail.FootwearValue.rubber
        default:                  return MatchFormatters.humanize(code)
        }
    }
}
