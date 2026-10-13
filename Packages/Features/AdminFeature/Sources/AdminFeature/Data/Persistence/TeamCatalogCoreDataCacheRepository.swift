import CoreData
import Foundation

final class TeamCatalogCoreDataCacheRepository: TeamCatalogCacheRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func saveTeams(_ items: [TeamVisualCatalogItem]) throws {
        try context.performAndWait {
            let existing = (try? self.context.fetch(CachedTeamCatalogEntity.fetchRequest())) ?? []
            existing.forEach { self.context.delete($0) }

            for item in items {
                let entity = CachedTeamCatalogEntity(context: self.context)
                entity.id = item.id
                entity.name = item.name
                entity.color = item.colorHex
                entity.cachedAt = Date()
            }
            try self.context.save()
        }
    }

    func loadTeams() -> [TeamVisualCatalogItem] {
        context.performAndWait {
            let request = CachedTeamCatalogEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            guard let results = try? self.context.fetch(request) else { return [] }
            return results.compactMap { entity in
                guard !entity.id.isEmpty, !entity.name.isEmpty else { return nil }
                return TeamVisualCatalogItem(id: entity.id, name: entity.name, colorHex: entity.color)
            }
        }
    }

    func clearTeams() throws {
        try context.performAndWait {
            let existing = (try? self.context.fetch(CachedTeamCatalogEntity.fetchRequest())) ?? []
            existing.forEach { self.context.delete($0) }
            if self.context.hasChanges { try self.context.save() }
        }
    }
}
