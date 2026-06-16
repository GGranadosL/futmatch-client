import CoreData
import Foundation

/// CoreData-backed cache for the admin fields list.
/// Follows the same pattern as `MatchCoreDataCacheRepository` in PlayerFeature.
final class AdminFieldsCoreDataCacheRepository: AdminFieldsCacheRepositoryProtocol {

    private let context: NSManagedObjectContext
    private let entityName = "CachedAdminFieldEntity"

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Save

    func saveFields(_ items: [AdminFieldItem]) throws {
        // Run on the context's own queue. CoreData contexts are NOT thread-safe;
        // these methods are called from background tasks, so touching `context`
        // directly corrupts its internal object set and crashes.
        try context.performAndWait {
            // Replace the cache atomically — delete all, then re-insert.
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let existing = (try? context.fetch(request)) ?? []
            existing.forEach { context.delete($0) }

            for item in items {
                guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else { continue }
                let object = NSManagedObject(entity: entity, insertInto: context)
                object.setValue(item.id,                    forKey: "id")
                object.setValue(item.name,                  forKey: "name")
                object.setValue(Int32(item.priceInCents),   forKey: "priceInCents")
                object.setValue(Int32(item.capacity),       forKey: "capacity")
                object.setValue(item.imageUrl,              forKey: "imageUrl")
                object.setValue(item.address,               forKey: "address")
                object.setValue(Date(),                     forKey: "cachedAt")
                // Detail fields — persisted so the field detail screen works offline.
                object.setValue(item.description,           forKey: "fieldDescription")
                object.setValue(item.rules,                 forKey: "rules")
                object.setValue(item.extraInfo,             forKey: "extraInfo")
                object.setValue(item.hasParking,            forKey: "hasParking")
                object.setValue(item.fieldType?.rawValue,   forKey: "fieldType")
                object.setValue(item.footwearType?.rawValue, forKey: "footwearType")
                object.setValue(encodeImages(item.images),  forKey: "imagesJSON")
            }
            try context.save()
        }
    }

    // MARK: - Load

    func loadFields() -> [AdminFieldItem] {
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            guard let results = try? context.fetch(request) else { return [] }
            return results.compactMap { map($0) }
        }
    }

    // MARK: - Clear

    func clearFields() throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let existing = (try? context.fetch(request)) ?? []
            existing.forEach { context.delete($0) }
            if context.hasChanges { try context.save() }
        }
    }

    // MARK: - Private

    private func map(_ object: NSManagedObject) -> AdminFieldItem? {
        guard
            let id   = object.value(forKey: "id")   as? String,
            let name = object.value(forKey: "name") as? String
        else { return nil }
        let fieldTypeRaw    = object.value(forKey: "fieldType")    as? String
        let footwearTypeRaw = object.value(forKey: "footwearType") as? String
        return AdminFieldItem(
            id:           id,
            name:         name,
            priceInCents: Int((object.value(forKey: "priceInCents") as? Int32) ?? 0),
            capacity:     Int((object.value(forKey: "capacity")     as? Int32) ?? 0),
            imageUrl:     object.value(forKey: "imageUrl") as? String,
            images:       decodeImages(object.value(forKey: "imagesJSON") as? String),
            address:      object.value(forKey: "address")  as? String,
            description:  object.value(forKey: "fieldDescription") as? String,
            rules:        object.value(forKey: "rules")     as? String,
            extraInfo:    object.value(forKey: "extraInfo") as? String,
            hasParking:   (object.value(forKey: "hasParking") as? Bool) ?? false,
            fieldType:    fieldTypeRaw.flatMap(FieldType.init(rawValue:)),
            footwearType: footwearTypeRaw.flatMap(FootwearType.init(rawValue:))
        )
    }

    // MARK: - Images JSON (de)serialization

    private func encodeImages(_ images: [FieldImage]) -> String {
        guard let data = try? JSONEncoder().encode(images),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    private func decodeImages(_ json: String?) -> [FieldImage] {
        guard let json, let data = json.data(using: .utf8),
              let images = try? JSONDecoder().decode([FieldImage].self, from: data) else { return [] }
        return images
    }
}
