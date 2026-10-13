import Foundation

/// Response for `GET /match/admin/teams`.
struct TeamCatalogResponseDTO: Decodable {
    let data: [TeamCatalogItemDTO]
}

struct TeamCatalogItemDTO: Decodable {
    let id: String
    let name: String
    let color: String

    func toDomain() -> TeamVisualCatalogItem {
        TeamVisualCatalogItem(id: id, name: name, colorHex: color)
    }
}
