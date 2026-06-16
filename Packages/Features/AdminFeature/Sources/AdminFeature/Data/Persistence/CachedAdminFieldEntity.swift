import CoreData

@objc(CachedAdminFieldEntity)
final class CachedAdminFieldEntity: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var priceInCents: Int32
    @NSManaged var capacity: Int32
    @NSManaged var imageUrl: String?
    @NSManaged var imagesJSON: String
    @NSManaged var address: String?
    @NSManaged var cachedAt: Date
    @NSManaged var fieldDescription: String?
    @NSManaged var rules: String?
    @NSManaged var extraInfo: String?
    @NSManaged var hasParking: Bool
    @NSManaged var fieldType: String?
    @NSManaged var footwearType: String?

    static func fetchRequest() -> NSFetchRequest<CachedAdminFieldEntity> {
        NSFetchRequest<CachedAdminFieldEntity>(entityName: "CachedAdminFieldEntity")
    }
}
