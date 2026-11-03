import Foundation

/// Which fields a user's field list shows.
///
/// The backend's `/fields/by-admin` returns only the fields the caller created
/// (or is a co-admin of), so an `ADMIN` who did not create a field would never
/// see it. Admins read `/fields/all` instead; organizers keep `/fields/by-admin`,
/// since `/fields/all` rejects them.
public enum FieldListScope: Equatable {
    /// Fields the caller created or co-administers (`GET /fields/by-admin`).
    case assigned
    /// Every field on the platform (`GET /fields/all`, `ADMIN` only).
    case all
}
