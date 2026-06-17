import CoreData

@objc(UserProfileEntity)
public final class UserProfileEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var lastName: String
    @NSManaged public var email: String
    @NSManaged public var phone: String
    @NSManaged public var status: String
    @NSManaged public var country: String
    @NSManaged public var birthDate: Date
    @NSManaged public var gender: String
    @NSManaged public var playerPosition: String
    @NSManaged public var profilePic: String
    @NSManaged public var level: String
    @NSManaged public var userRole: String
    @NSManaged public var isEmailVerified: Bool
    @NSManaged public var cachedAt: Date

    public static func fetchRequest() -> NSFetchRequest<UserProfileEntity> {
        NSFetchRequest<UserProfileEntity>(entityName: "UserProfileEntity")
    }
}
