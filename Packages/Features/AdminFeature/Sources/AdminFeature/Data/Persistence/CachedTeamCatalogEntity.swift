import CoreData

@objc(CachedTeamCatalogEntity)
final class CachedTeamCatalogEntity: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var color: String
    @NSManaged var cachedAt: Date

    static func fetchRequest() -> NSFetchRequest<CachedTeamCatalogEntity> {
        NSFetchRequest<CachedTeamCatalogEntity>(entityName: "CachedTeamCatalogEntity")
    }
}
