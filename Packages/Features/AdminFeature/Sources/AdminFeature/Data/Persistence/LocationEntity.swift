import CoreData

@objc(LocationEntity)
final class LocationEntity: NSManagedObject {
    @NSManaged var id: String?
    @NSManaged var address: String?
    @NSManaged var country: String?
    @NSManaged var city: String?
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var createdAt: Date?

    static func fetchRequest() -> NSFetchRequest<LocationEntity> {
        NSFetchRequest<LocationEntity>(entityName: "LocationEntity")
    }
}
