import Foundation

// MARK: - Request

/// Body for `POST /fields/create`. Mirrors the backend `CreateFieldRequest`.
struct CreateFieldRequest: Encodable {
    let name: String
    let priceInCents: Int
    let capacity: Int
    let description: String
    let rules: String
    let footwearType: String?
    let fieldType: String?
    let hasParking: Bool
    let extraInfo: String?

    init(params: CreateFieldParams) {
        self.name = params.name
        self.priceInCents = params.priceInCents
        self.capacity = params.capacity
        self.description = params.description
        self.rules = params.rules
        self.footwearType = params.footwearType?.rawValue
        self.fieldType = params.fieldType?.rawValue
        self.hasParking = params.hasParking
        self.extraInfo = params.extraInfo
    }
}

// MARK: - Update Request

/// Body for `POST /fields/update`. Mirrors the backend `UpdateFieldRequest`.
struct UpdateFieldRequest: Encodable {
    let fieldId: String
    let name: String
    let priceInCents: Int
    let capacity: Int
    let description: String
    let rules: String
    let footwearType: String?
    let fieldType: String?
    let hasParking: Bool
    let extraInfo: String?
    let locationId: String?   // optional — future use when location feature ships

    init(fieldId: String, params: CreateFieldParams, locationId: String? = nil) {
        self.fieldId      = fieldId
        self.name         = params.name
        self.priceInCents = params.priceInCents
        self.capacity     = params.capacity
        self.description  = params.description
        self.rules        = params.rules
        self.footwearType = params.footwearType?.rawValue
        self.fieldType    = params.fieldType?.rawValue
        self.hasParking   = params.hasParking
        self.extraInfo    = params.extraInfo
        self.locationId   = locationId
    }
}

/// Response for `POST /fields/update` — `data` is just `true` on success.
struct UpdateFieldResponse: Decodable {
    let data: Bool
}

// MARK: - Create Response

struct CreateFieldResponse: Decodable {
    let data: FieldDTO
}

// MARK: - By-Admin List Response

struct AdminFieldsResponse: Decodable {
    let data: [AdminFieldEntryDTO]
}

struct AdminFieldEntryDTO: Decodable {
    let field: AdminFieldDTO
    let images: [FieldImageDTO]

    func toDomain() -> AdminFieldItem {
        let sortedImages = images.sorted { $0.position < $1.position }
        return AdminFieldItem(
            id: field.id,
            name: field.name,
            priceInCents: field.priceInCents,
            capacity: field.capacity,
            imageUrl: sortedImages.first?.imagePath,
            images: sortedImages.map {
                FieldImage(id: $0.id, url: $0.imagePath, position: $0.position)
            },
            address: field.location?.address,
            description: field.description,
            rules: field.rules,
            extraInfo: field.extraInfo,
            hasParking: field.hasParking ?? false,
            fieldType: field.fieldType.flatMap(FieldType.init(rawValue:)),
            footwearType: field.footwearType.flatMap(FootwearType.init(rawValue:))
        )
    }
}

struct AdminFieldDTO: Decodable {
    let id: String
    let name: String
    let priceInCents: Int
    let capacity: Int
    let description: String
    let rules: String
    let footwearType: String?
    let fieldType: String?
    let hasParking: Bool?
    let extraInfo: String?
    let location: FieldLocationDTO?
}

struct FieldLocationDTO: Decodable {
    let id: String
    let address: String
    let cityCode: String?
    let countryCode: String?
    let latitude: Double?
    let longitude: Double?
}

struct FieldImageDTO: Decodable {
    let id: String
    let fieldId: String
    let imagePath: String
    let position: Int
}

/// Response for the field image endpoints. `data` is the image UUID on
/// upload/replace, and a success message string on delete.
struct FieldImageMutationResponse: Decodable {
    let data: String
}

/// DTO for `GET /fields/id-name` — catalog used in match-creation pickers.
struct FieldIdNameDTO: Decodable {
    let id: String
    let name: String
}

struct FieldDTO: Decodable {
    let id: String
    let name: String
    let priceInCents: Int
    let capacity: Int
    let description: String
    let rules: String
    let footwearType: String?
    let fieldType: String?
    let hasParking: Bool?
    let extraInfo: String?

    func toDomain() -> Field {
        Field(
            id: id,
            name: name,
            priceInCents: priceInCents,
            capacity: capacity,
            description: description,
            rules: rules,
            footwearType: footwearType.flatMap(FootwearType.init(rawValue:)),
            fieldType: fieldType.flatMap(FieldType.init(rawValue:)),
            hasParking: hasParking ?? false,
            extraInfo: extraInfo
        )
    }
}
