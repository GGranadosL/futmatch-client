import CoreData
import Foundation

// MARK: - Match CoreData Cache Repository

final class MatchCoreDataCacheRepository: MatchCacheRepositoryProtocol {

    private let context: NSManagedObjectContext
    private let entityClass: CachedMatchEntity.Type
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: NSManagedObjectContext, entityClass: CachedMatchEntity.Type = CachedMatchEntity.self) {
        self.context = context
        self.entityClass = entityClass
    }

    // MARK: - Save

    func saveMatches(_ items: [MatchItem]) throws {
        try context.performAndWait {
            let request = self.entityClass.fetchRequest()
            let existing = try self.context.fetch(request)
            existing.forEach { self.context.delete($0) }

            for item in items {
                let entity = self.entityClass.init(context: self.context)
                entity.id = item.id
                entity.venueName = item.venueName
                entity.location = item.location
                entity.timeRange = item.timeRange
                entity.date = item.date
                entity.startDate = item.startDate
                entity.price = item.price
                entity.matchType = item.matchType
                entity.spotsLeft = Int32(item.spotsLeft)
                entity.teamAMax = Int32(item.teamAMax)
                entity.teamBMax = Int32(item.teamBMax)
                entity.distance = item.distance
                entity.duration = item.duration
                entity.fieldImageUrl = item.fieldImageUrl
                entity.shoeType = item.shoeType
                entity.fieldType = item.fieldType
                entity.hasParking = item.hasParking
                entity.extraInfo = item.extraInfo
                entity.teamAPlayersJSON = self.encodePlayers(item.teamAPlayers)
                entity.teamBPlayersJSON = self.encodePlayers(item.teamBPlayers)
                entity.rulesJSON = self.encodeRules(item.rules)
                entity.matchStatus = item.matchStatus
                entity.cachedAt = Date()
            }

            try self.context.save()
        }
    }

    // MARK: - Load

    func loadMatches() -> [MatchItem] {
        context.performAndWait {
            let request = self.entityClass.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            guard let results = try? self.context.fetch(request) else { return [] }
            return results.compactMap { mapToMatchItem($0) }
        }
    }

    // MARK: - Clear

    func clearMatches() throws {
        try context.performAndWait {
            let request = self.entityClass.fetchRequest()
            let existing = try self.context.fetch(request)
            existing.forEach { self.context.delete($0) }
            if self.context.hasChanges { try self.context.save() }
        }
    }

    // MARK: - Private Mapping

    private func mapToMatchItem(_ entity: CachedMatchEntity) -> MatchItem? {
        MatchItem(
            id: entity.id,
            venueName: entity.venueName,
            location: entity.location,
            timeRange: entity.timeRange,
            date: entity.date,
            startDate: entity.startDate,
            price: entity.price,
            matchType: entity.matchType,
            spotsLeft: Int(entity.spotsLeft),
            teamAPlayers: decodePlayers(entity.teamAPlayersJSON),
            teamBPlayers: decodePlayers(entity.teamBPlayersJSON),
            teamAMax: Int(entity.teamAMax),
            teamBMax: Int(entity.teamBMax),
            distance: entity.distance,
            duration: entity.duration,
            fieldImageUrl: entity.fieldImageUrl,
            shoeType: entity.shoeType,
            fieldType: entity.fieldType,
            hasParking: entity.hasParking,
            extraInfo: entity.extraInfo,
            rules: decodeRules(entity.rulesJSON),
            matchStatus: entity.matchStatus
        )
    }

    // MARK: - JSON Helpers

    private func encodePlayers(_ players: [MatchPlayer]) -> String {
        let cached = players.map(CachedPlayer.init)
        return (try? encoder.encode(cached)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private func decodePlayers(_ json: String) -> [MatchPlayer] {
        guard let data = json.data(using: .utf8),
              let cached = try? decoder.decode([CachedPlayer].self, from: data) else { return [] }
        return cached.map { MatchPlayer(id: $0.id, name: $0.name, avatarUrl: $0.avatarUrl, status: $0.status.uppercased() == "RESERVED" ? .reserved : .joined) }
    }

    private func encodeRules(_ rules: [String]) -> String {
        (try? encoder.encode(rules)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private func decodeRules(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
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
