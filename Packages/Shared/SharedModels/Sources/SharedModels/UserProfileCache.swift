import CoreData
import Foundation

// MARK: - Protocol

public protocol UserProfileCacheProtocol {
    func save(_ user: User) throws
    func load() -> User?
    func clear() throws
}

// MARK: - CoreData Implementation

public final class UserProfileCoreDataRepository: UserProfileCacheProtocol {

    private let context: NSManagedObjectContext
    private static let entityName = "UserProfileEntity"

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func save(_ user: User) throws {
        // Run on the context's own queue. CoreData contexts are NOT thread-safe;
        // this is called from background tasks, so touching `context` directly
        // corrupts its internal object set and crashes.
        try context.performAndWait {
            // Keep only the latest profile — delete any existing entry first
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            let existing = try context.fetch(request)
            existing.forEach { context.delete($0) }

            guard let entity = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else { return }
            let object = NSManagedObject(entity: entity, insertInto: context)
            object.setValue(user.id, forKey: "id")
            object.setValue(user.name, forKey: "name")
            object.setValue(user.lastName, forKey: "lastName")
            object.setValue(user.email, forKey: "email")
            object.setValue(user.phone, forKey: "phone")
            object.setValue(user.status.rawValue, forKey: "status")
            object.setValue(user.country, forKey: "country")
            object.setValue(user.birthDate, forKey: "birthDate")
            object.setValue(user.gender?.rawValue, forKey: "gender")
            object.setValue(user.playerPosition.rawValue, forKey: "playerPosition")
            object.setValue(user.profilePic, forKey: "profilePic")
            object.setValue(user.level.rawValue, forKey: "level")
            object.setValue(user.userRole.rawValue, forKey: "userRole")
            object.setValue(user.isEmailVerified, forKey: "isEmailVerified")
            object.setValue(Date(), forKey: "cachedAt")
            try context.save()
        }
    }

    public func load() -> User? {
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            request.fetchLimit = 1
            guard let object = try? context.fetch(request).first else { return nil }

            guard
                let id = object.value(forKey: "id") as? String,
                let name = object.value(forKey: "name") as? String,
                let lastName = object.value(forKey: "lastName") as? String,
                let country = object.value(forKey: "country") as? String,
                let positionRaw = object.value(forKey: "playerPosition") as? String,
                let profilePic = object.value(forKey: "profilePic") as? String,
                let levelRaw = object.value(forKey: "level") as? String
            else { return nil }

            let genderRaw = object.value(forKey: "gender") as? String
            let gender = genderRaw.flatMap { Gender(rawValue: $0) }

            return User(
                id: id,
                name: name,
                lastName: lastName,
                email: object.value(forKey: "email") as? String ?? "",
                phone: object.value(forKey: "phone") as? String ?? "",
                status: (object.value(forKey: "status") as? String).flatMap { UserStatus(rawValue: $0) } ?? .active,
                country: country,
                birthDate: object.value(forKey: "birthDate") as? Date ?? Date(),
                gender: gender,
                playerPosition: PlayerPosition(rawValue: positionRaw) ?? .midfielder,
                profilePic: profilePic,
                level: PlayerLevel(rawValue: levelRaw) ?? .beginner,
                userRole: (object.value(forKey: "userRole") as? String).flatMap { UserRole(rawValue: $0) } ?? .player,
                isEmailVerified: object.value(forKey: "isEmailVerified") as? Bool ?? false
            )
        }
    }

    public func clear() throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            let existing = try context.fetch(request)
            existing.forEach { context.delete($0) }
            if context.hasChanges {
                try context.save()
            }
        }
    }
}
