import Foundation

// MARK: - Field

/// Domain entity for a field (cancha).
public struct Field: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let priceInCents: Int
    public let capacity: Int
    public let description: String
    public let rules: String
    public let footwearType: FootwearType?
    public let fieldType: FieldType?
    public let hasParking: Bool
    public let extraInfo: String?

    public init(
        id: String,
        name: String,
        priceInCents: Int,
        capacity: Int,
        description: String,
        rules: String,
        footwearType: FootwearType?,
        fieldType: FieldType?,
        hasParking: Bool,
        extraInfo: String?
    ) {
        self.id = id
        self.name = name
        self.priceInCents = priceInCents
        self.capacity = capacity
        self.description = description
        self.rules = rules
        self.footwearType = footwearType
        self.fieldType = fieldType
        self.hasParking = hasParking
        self.extraInfo = extraInfo
    }
}

// MARK: - CreateFieldParams

/// Validated input for creating a field. Built by the ViewModel from the form
/// and consumed by `CreateFieldUseCase`.
public struct CreateFieldParams: Equatable {
    public let name: String
    public let priceInCents: Int
    public let capacity: Int
    public let description: String
    public let rules: String
    public let footwearType: FootwearType?
    public let fieldType: FieldType?
    public let hasParking: Bool
    public let extraInfo: String?

    public init(
        name: String,
        priceInCents: Int,
        capacity: Int,
        description: String,
        rules: String,
        footwearType: FootwearType?,
        fieldType: FieldType?,
        hasParking: Bool,
        extraInfo: String?
    ) {
        self.name = name
        self.priceInCents = priceInCents
        self.capacity = capacity
        self.description = description
        self.rules = rules
        self.footwearType = footwearType
        self.fieldType = fieldType
        self.hasParking = hasParking
        self.extraInfo = extraInfo
    }
}
