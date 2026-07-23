import Foundation

/// A user with `ADMIN` or `ORGANIZER` role who can be assigned as a match supervisor.
/// Returned by `GET /user/admin/organizers`.
public struct Organizer: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let lastName: String

    public init(id: String, name: String, lastName: String) {
        self.id = id
        self.name = name
        self.lastName = lastName
    }

    public var fullName: String {
        "\(name) \(lastName)"
    }
}
