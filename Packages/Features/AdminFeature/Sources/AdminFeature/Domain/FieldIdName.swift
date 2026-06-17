import Foundation

/// Lightweight field model used in pickers/dropdowns (e.g. match creation).
/// Returned by `GET /fields/id-name`.
public struct FieldIdName: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
}
