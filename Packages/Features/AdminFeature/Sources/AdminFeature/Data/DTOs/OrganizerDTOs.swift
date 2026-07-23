import Foundation

/// Response for `GET /user/admin/organizers`.
struct OrganizersResponseDTO: Decodable {
    let data: [OrganizerDTO]
}

struct OrganizerDTO: Decodable {
    let id: String
    let name: String
    let lastName: String

    func toDomain() -> Organizer {
        Organizer(id: id, name: name, lastName: lastName)
    }
}
