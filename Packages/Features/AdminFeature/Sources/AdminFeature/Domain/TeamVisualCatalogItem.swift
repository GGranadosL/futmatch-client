import Foundation
import FMDesignSystem

/// Selectable team identity from the backend catalog (`GET /match/admin/teams`).
public struct TeamVisualCatalogItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    /// `#RRGGBB`.
    public let colorHex: String

    public init(id: String, name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    /// Whether this catalog entry matches a match's stored snapshot. The match
    /// only carries a name/color copy, not the catalog id, so edit screens use
    /// this to preselect the dropdown.
    public func matches(_ visual: AdminMatchTeamVisual) -> Bool {
        name == visual.name && colorHex.caseInsensitiveCompare(visual.colorHex ?? "") == .orderedSame
    }
}

extension TeamVisualCatalogItem: FMDropdownOption {
    public var displayName: String { name }
    public var leadingColorHex: String? { colorHex }
}
