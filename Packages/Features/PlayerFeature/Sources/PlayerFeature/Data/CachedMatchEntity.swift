import CoreData

@objc(CachedMatchEntity)
class CachedMatchEntity: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var venueName: String
    @NSManaged var location: String
    @NSManaged var timeRange: String
    @NSManaged var date: String
    @NSManaged var startDate: Date
    @NSManaged var price: String
    @NSManaged var matchType: String
    @NSManaged var spotsLeft: Int32
    @NSManaged var teamAMax: Int32
    @NSManaged var teamBMax: Int32
    @NSManaged var distance: String
    @NSManaged var duration: String
    @NSManaged var fieldImageUrl: String?
    @NSManaged var shoeType: String
    @NSManaged var fieldType: String
    @NSManaged var hasParking: Bool
    @NSManaged var extraInfo: String?
    @NSManaged var teamAPlayersJSON: String
    @NSManaged var teamBPlayersJSON: String
    @NSManaged var rulesJSON: String
    @NSManaged var matchStatus: String
    @NSManaged var cachedAt: Date

    class func fetchRequest() -> NSFetchRequest<CachedMatchEntity> {
        NSFetchRequest<CachedMatchEntity>(entityName: "CachedMatchEntity")
    }
}

@objc(CachedReservedMatchEntity)
final class CachedReservedMatchEntity: CachedMatchEntity {
    override class func fetchRequest() -> NSFetchRequest<CachedMatchEntity> {
        NSFetchRequest<CachedMatchEntity>(entityName: "CachedReservedMatchEntity")
    }
}
