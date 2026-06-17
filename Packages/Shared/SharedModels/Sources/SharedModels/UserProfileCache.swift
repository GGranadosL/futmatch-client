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

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func save(_ user: User) throws {
        try context.performAndWait {
            let existing = (try? self.context.fetch(UserProfileEntity.fetchRequest())) ?? []
            existing.forEach { self.context.delete($0) }

            let entity = UserProfileEntity(context: self.context)
            entity.id = user.id
            entity.name = user.name
            entity.lastName = user.lastName
            entity.email = user.email
            entity.phone = user.phone
            entity.status = user.status.rawValue
            entity.country = user.country
            entity.birthDate = user.birthDate
            entity.gender = user.gender?.rawValue ?? ""
            entity.playerPosition = user.playerPosition.rawValue
            entity.profilePic = user.profilePic
            entity.level = user.level.rawValue
            entity.userRole = user.userRole.rawValue
            entity.isEmailVerified = user.isEmailVerified
            entity.cachedAt = Date()
            try self.context.save()
        }
    }

    public func load() -> User? {
        context.performAndWait {
            let request = UserProfileEntity.fetchRequest()
            request.fetchLimit = 1
            guard let entity = try? self.context.fetch(request).first else { return nil }

            return User(
                id: entity.id,
                name: entity.name,
                lastName: entity.lastName,
                email: entity.email,
                phone: entity.phone,
                status: UserStatus(rawValue: entity.status) ?? .active,
                country: entity.country,
                birthDate: entity.birthDate,
                gender: entity.gender.isEmpty ? nil : Gender(rawValue: entity.gender),
                playerPosition: PlayerPosition(rawValue: entity.playerPosition) ?? .midfielder,
                profilePic: entity.profilePic,
                level: PlayerLevel(rawValue: entity.level) ?? .beginner,
                userRole: UserRole(rawValue: entity.userRole) ?? .player,
                isEmailVerified: entity.isEmailVerified
            )
        }
    }

    public func clear() throws {
        try context.performAndWait {
            let existing = (try? self.context.fetch(UserProfileEntity.fetchRequest())) ?? []
            existing.forEach { self.context.delete($0) }
            if self.context.hasChanges { try self.context.save() }
        }
    }
}
