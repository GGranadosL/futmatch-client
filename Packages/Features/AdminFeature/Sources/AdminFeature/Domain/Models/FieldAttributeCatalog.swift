import Foundation

// MARK: - Field Attribute Catalog Models

/// A selectable field-type or footwear-type option, as exposed by the catalog.
///
/// Carries both languages because PlayerFeature (bilingual UI) reuses this
/// same catalog/repository to display match details — AdminFeature's own UI
/// is Spanish-only, so `displayName` always resolves to `nameEs`.
public struct FieldAttributeOption: Codable, Equatable, Hashable, CustomStringConvertible {
    public let code: String
    public let nameEs: String
    public let nameEn: String

    public init(code: String, nameEs: String, nameEn: String) {
        self.code = code
        self.nameEs = nameEs
        self.nameEn = nameEn
    }

    /// AdminFeature's UI is Spanish-only regardless of device locale.
    public var displayName: String { nameEs }

    public var description: String { displayName }
}

/// The two independent catalogs used by the field creation/edit forms.
public struct FieldAttributeCatalogs: Codable, Equatable {
    public let fieldTypes: [FieldAttributeOption]
    public let footwearTypes: [FieldAttributeOption]

    public init(fieldTypes: [FieldAttributeOption], footwearTypes: [FieldAttributeOption]) {
        self.fieldTypes = fieldTypes
        self.footwearTypes = footwearTypes
    }
}

public extension FieldAttributeCatalogs {
    /// Catalogs built from the hardcoded `FieldType`/`FootwearType` enums — used
    /// when Remote Config has no value yet (first launch offline) or fails to parse.
    static var fallback: FieldAttributeCatalogs {
        FieldAttributeCatalogs(
            fieldTypes: FieldType.allCases.map {
                FieldAttributeOption(code: $0.rawValue, nameEs: $0.displayName, nameEn: $0.displayName)
            },
            footwearTypes: FootwearType.allCases.map {
                FieldAttributeOption(code: $0.rawValue, nameEs: $0.displayName, nameEn: $0.displayName)
            }
        )
    }
}
