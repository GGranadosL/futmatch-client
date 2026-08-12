import Foundation

/// Source of the field-type/footwear-type catalogs used by the field forms.
public protocol FieldAttributeCatalogRepositoryProtocol {
    /// Never throws — implementations fall back to the hardcoded catalog.
    func fetchCatalogs() async -> FieldAttributeCatalogs
}
