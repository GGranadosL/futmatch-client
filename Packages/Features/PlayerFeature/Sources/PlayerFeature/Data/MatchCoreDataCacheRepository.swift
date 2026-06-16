import CoreData
import Foundation

// MARK: - Match CoreData Cache Repository

final class MatchCoreDataCacheRepository: MatchCacheRepositoryProtocol {

    private let context: NSManagedObjectContext
    private let entityName: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: NSManagedObjectContext, entityName: String = "CachedMatchEntity") {
        self.context = context
        self.entityName = entityName
    }

    // MARK: - Save

    func saveMatches(_ items: [MatchItem]) throws {
        // Run on the context's own queue. CoreData contexts are NOT thread-safe;
        // these methods are called from background tasks, so touching `context`
        // directly corrupts its internal object set and crashes.
        try context.performAndWait {
            // Replace entire cache atomically
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let existing = try context.fetch(request)
            existing.forEach { context.delete($0) }

            for item in items {
                guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else { continue }
                let object = NSManagedObject(entity: entity, insertInto: context)
                object.setValue(item.id, forKey: "id")
                object.setValue(item.venueName, forKey: "venueName")
                object.setValue(item.location, forKey: "location")
                object.setValue(item.timeRange, forKey: "timeRange")
                object.setValue(item.date, forKey: "date")
                object.setValue(item.startDate, forKey: "startDate")
                object.setValue(item.price, forKey: "price")
                object.setValue(item.matchType, forKey: "matchType")
                object.setValue(item.spotsLeft, forKey: "spotsLeft")
                object.setValue(item.teamAMax, forKey: "teamAMax")
                object.setValue(item.teamBMax, forKey: "teamBMax")
                object.setValue(item.distance, forKey: "distance")
                object.setValue(item.duration, forKey: "duration")
                object.setValue(item.fieldImageUrl, forKey: "fieldImageUrl")
                object.setValue(item.shoeType, forKey: "shoeType")
                object.setValue(item.fieldType, forKey: "fieldType")
                object.setValue(item.hasParking, forKey: "hasParking")
                object.setValue(item.extraInfo, forKey: "extraInfo")
                object.setValue(encodePlayers(item.teamAPlayers), forKey: "teamAPlayersJSON")
                object.setValue(encodePlayers(item.teamBPlayers), forKey: "teamBPlayersJSON")
                object.setValue(encodeRules(item.rules), forKey: "rulesJSON")
                object.setValue(item.matchStatus, forKey: "matchStatus")
                object.setValue(Date(), forKey: "cachedAt")
            }

            try context.save()
        }
    }

    // MARK: - Load

    func loadMatches() -> [MatchItem] {
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            guard let results = try? context.fetch(request) else { return [] }
            return results.compactMap { mapToMatchItem($0) }
        }
    }

    // MARK: - Clear

    func clearMatches() throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let existing = try context.fetch(request)
            existing.forEach { context.delete($0) }
            if context.hasChanges {
                try context.save()
            }
        }
    }

    // MARK: - Private Mapping

    private func mapToMatchItem(_ object: NSManagedObject) -> MatchItem? {
        guard
            let id = object.value(forKey: "id") as? String,
            let venueName = object.value(forKey: "venueName") as? String,
            let location = object.value(forKey: "location") as? String,
            let timeRange = object.value(forKey: "timeRange") as? String,
            let date = object.value(forKey: "date") as? String,
            let startDate = object.value(forKey: "startDate") as? Date,
            let price = object.value(forKey: "price") as? String,
            let matchType = object.value(forKey: "matchType") as? String
        else { return nil }

        return MatchItem(
            id: id,
            venueName: venueName,
            location: location,
            timeRange: timeRange,
            date: date,
            startDate: startDate,
            price: price,
            matchType: matchType,
            spotsLeft: object.value(forKey: "spotsLeft") as? Int ?? 0,
            teamAPlayers: decodePlayers(object.value(forKey: "teamAPlayersJSON") as? String),
            teamBPlayers: decodePlayers(object.value(forKey: "teamBPlayersJSON") as? String),
            teamAMax: object.value(forKey: "teamAMax") as? Int ?? 5,
            teamBMax: object.value(forKey: "teamBMax") as? Int ?? 5,
            distance: object.value(forKey: "distance") as? String ?? "",
            duration: object.value(forKey: "duration") as? String ?? "60 min",
            fieldImageUrl: object.value(forKey: "fieldImageUrl") as? String,
            shoeType: object.value(forKey: "shoeType") as? String ?? "",
            fieldType: object.value(forKey: "fieldType") as? String ?? "",
            hasParking: object.value(forKey: "hasParking") as? Bool ?? false,
            extraInfo: object.value(forKey: "extraInfo") as? String,
            rules: decodeRules(object.value(forKey: "rulesJSON") as? String),
            matchStatus: object.value(forKey: "matchStatus") as? String ?? ""
        )
    }

    // MARK: - JSON Helpers

    private func encodePlayers(_ players: [MatchPlayer]) -> String {
        let cached = players.map(CachedPlayer.init)
        return (try? encoder.encode(cached)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private func decodePlayers(_ json: String?) -> [MatchPlayer] {
        guard let json, let data = json.data(using: .utf8),
              let cached = try? decoder.decode([CachedPlayer].self, from: data) else { return [] }
        return cached.map { MatchPlayer(id: $0.id, name: $0.name, avatarUrl: $0.avatarUrl, status: $0.status.uppercased() == "RESERVED" ? .reserved : .joined) }
    }

    private func encodeRules(_ rules: [String]) -> String {
        (try? encoder.encode(rules)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private func decodeRules(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8),
              let result = try? decoder.decode([String].self, from: data) else { return [] }
        return result
    }
}

// MARK: - Serializable Player

private struct CachedPlayer: Codable {
    let id: String
    let name: String
    let avatarUrl: String?
    let status: String

    init(_ player: MatchPlayer) {
        id = player.id
        name = player.name
        avatarUrl = player.avatarUrl
        status = player.status.rawValue
    }
}
