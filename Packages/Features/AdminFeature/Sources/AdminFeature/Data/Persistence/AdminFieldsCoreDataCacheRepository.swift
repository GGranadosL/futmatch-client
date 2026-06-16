import CoreData
import Foundation

final class AdminFieldsCoreDataCacheRepository: AdminFieldsCacheRepositoryProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Save

    func saveFields(_ items: [AdminFieldItem]) throws {
        try context.performAndWait {
            let existing = (try? self.context.fetch(CachedAdminFieldEntity.fetchRequest())) ?? []
            existing.forEach { self.context.delete($0) }

            for item in items {
                let entity = CachedAdminFieldEntity(context: self.context)
                entity.id = item.id
                entity.name = item.name
                entity.priceInCents = Int32(item.priceInCents)
                entity.capacity = Int32(item.capacity)
                entity.imageUrl = item.imageUrl
                entity.imagesJSON = encodeImages(item.images)
                entity.address = item.address
                entity.cachedAt = Date()
                entity.fieldDescription = item.description
                entity.rules = item.rules
                entity.extraInfo = item.extraInfo
                entity.hasParking = item.hasParking
                entity.fieldType = item.fieldType?.rawValue
                entity.footwearType = item.footwearType?.rawValue
            }
            try self.context.save()
        }
    }

    // MARK: - Load

    func loadFields() -> [AdminFieldItem] {
        context.performAndWait {
            let request = CachedAdminFieldEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            guard let results = try? self.context.fetch(request) else { return [] }
            return results.compactMap { map($0) }
        }
    }

    // MARK: - Clear

    func clearFields() throws {
        try context.performAndWait {
            let existing = (try? self.context.fetch(CachedAdminFieldEntity.fetchRequest())) ?? []
            existing.forEach { self.context.delete($0) }
            if self.context.hasChanges { try self.context.save() }
        }
    }

    // MARK: - Private

    private func map(_ entity: CachedAdminFieldEntity) -> AdminFieldItem? {
        guard !entity.id.isEmpty, !entity.name.isEmpty else { return nil }
        return AdminFieldItem(
            id: entity.id,
            name: entity.name,
            priceInCents: Int(entity.priceInCents),
            capacity: Int(entity.capacity),
            imageUrl: entity.imageUrl,
            images: decodeImages(entity.imagesJSON),
            address: entity.address,
            description: entity.fieldDescription,
            rules: entity.rules,
            extraInfo: entity.extraInfo,
            hasParking: entity.hasParking,
            fieldType: entity.fieldType.flatMap(FieldType.init(rawValue:)),
            footwearType: entity.footwearType.flatMap(FootwearType.init(rawValue:))
        )
    }

    private func encodeImages(_ images: [FieldImage]) -> String {
        guard let data = try? JSONEncoder().encode(images),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    private func decodeImages(_ json: String) -> [FieldImage] {
        guard let data = json.data(using: .utf8),
              let images = try? JSONDecoder().decode([FieldImage].self, from: data) else { return [] }
        return images
    }
}
