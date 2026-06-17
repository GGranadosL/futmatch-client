import Foundation

/// A single image attached to a field.
///
/// Carries the backend `id` (needed to replace/delete) and the `position`
/// (0-based slot index, where `0` is the primary image).
public struct FieldImage: Identifiable, Equatable, Hashable, Codable {
    public let id: String
    public let url: String
    public let position: Int

    public init(id: String, url: String, position: Int) {
        self.id = id
        self.url = url
        self.position = position
    }
}
