import Foundation

/// Domain model used across the admin fields list and detail/edit screens.
///
/// Basic fields (`id`, `name`, `priceInCents`, `capacity`, `imageUrl`, `address`)
/// are stored in CoreData and available even when offline.
/// Detail fields (`description`, `rules`, etc.) are only populated when the
/// item is freshly loaded from the API — they are `nil` when restored from cache.
public struct AdminFieldItem: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let priceInCents: Int
    public let capacity: Int
    /// Primary image URL (lowest `position` value from the `images` array).
    public let imageUrl: String?
    /// All images attached to the field, sorted by `position`. Populated when
    /// loaded fresh from the API; empty when restored from the CoreData cache
    /// (which only persists the primary `imageUrl`).
    public let images: [FieldImage]
    /// Street address from `field.location.address`.
    public let address: String?

    // MARK: - Detail fields (nil when loaded from CoreData cache)

    public let description: String?
    public let rules: String?
    public let extraInfo: String?
    public let hasParking: Bool
    public let fieldType: FieldType?
    public let footwearType: FootwearType?

    // MARK: - Location

    public let locationId: String?
    public let assignedLocation: AdminLocation?

    public init(
        id: String,
        name: String,
        priceInCents: Int,
        capacity: Int,
        imageUrl: String? = nil,
        images: [FieldImage] = [],
        address: String? = nil,
        description: String? = nil,
        rules: String? = nil,
        extraInfo: String? = nil,
        hasParking: Bool = false,
        fieldType: FieldType? = nil,
        footwearType: FootwearType? = nil,
        locationId: String? = nil,
        assignedLocation: AdminLocation? = nil
    ) {
        self.id = id
        self.name = name
        self.priceInCents = priceInCents
        self.capacity = capacity
        self.imageUrl = imageUrl
        self.images = images
        self.address = address
        self.description = description
        self.rules = rules
        self.extraInfo = extraInfo
        self.hasParking = hasParking
        self.fieldType = fieldType
        self.footwearType = footwearType
        self.locationId = locationId
        self.assignedLocation = assignedLocation
    }

    /// Price formatted for display, e.g. "$38.00".
    public var formattedPrice: String {
        String(format: "$%.2f", Double(priceInCents) / 100.0)
    }
}
