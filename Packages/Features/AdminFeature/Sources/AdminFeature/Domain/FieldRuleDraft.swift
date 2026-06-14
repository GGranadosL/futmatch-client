import Foundation

// MARK: - FieldRuleDraft

/// One editable rule row in the field form. Identifiable so SwiftUI keeps each
/// text field stable across insertions and removals in the rules editor.
public struct FieldRuleDraft: Identifiable, Equatable {
    public let id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}
