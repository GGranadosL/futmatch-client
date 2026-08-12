import Foundation

// MARK: - Versioned List Response (V2)

/// Envelope for `GET /match/matches/v2`. When `hasChanges == false` the backend
/// omits `matches` (the client keeps its current list); otherwise it sends the
/// full list plus the new `currentVersion`.
struct MatchesV2Response: Decodable {
    let data: MatchesV2Data
}

struct MatchesV2Data: Decodable {
    let region: String
    let currentVersion: Int64
    let hasChanges: Bool
    let matches: [MatchListItemV2DTO]?
}

/// List item for the versioned feed. Unlike the legacy DTO it carries
/// `maxPlayers` — the *fixed* capacity, which the capacity contract makes the
/// source of truth for spots/missing calculations.
struct MatchListItemV2DTO: Decodable {
    let id: String
    let fieldName: String
    let fieldImages: [FieldImageDTO]?
    let startTime: Int64
    let endTime: Int64
    let originalPriceInCents: Int
    let totalDiscountInCents: Int
    let priceInCents: Int
    let genderType: String
    let status: String
    let maxPlayers: Int
    /// Backend snapshot — kept for reference but recomputed from `maxPlayers`.
    let availableSpots: Int?
    let teams: MatchTeamsDTO
    let location: MatchLocationV2DTO?
    let teamAScore: Int?
    let teamBScore: Int?
    let winnerTeam: String?

    var resolvedFieldImageUrl: String? { fieldImages?.compactMap(\.imagePath).first }

    func toMatchItem() -> MatchItem {
        let (start, end) = MatchFormatters.dates(startMs: startTime, endMs: endTime)
        // Capacity contract: `maxPlayers` is the fixed total capacity and the
        // source of truth. Spots per team and available spots are derived from
        // it and the per-team `playerCount`, never from the snapshot.
        let spotsPerTeam = max(1, maxPlayers / 2)
        let occupied = teams.teamA.playerCount + teams.teamB.playerCount
        let computedAvailable = max(0, maxPlayers - occupied)
        return MatchItem(
            id: id,
            venueName: fieldName,
            location: MatchLocationV2DTO.displayString(location),
            timeRange: MatchFormatters.timeRange(start: start, end: end),
            date: MatchFormatters.dateString(start),
            startDate: start,
            price: MatchFormatters.priceString(priceInCents),
            matchType: MatchFormatters.genderLabel(genderType),
            spotsLeft: computedAvailable,
            teamAPlayers: teams.teamA.players.map { $0.toMatchPlayer() },
            teamBPlayers: teams.teamB.players.map { $0.toMatchPlayer() },
            teamAMax: spotsPerTeam,
            teamBMax: spotsPerTeam,
            distance: "",
            duration: MatchFormatters.durationString(start: start, end: end),
            fieldImageUrl: resolvedFieldImageUrl,
            shoeType: "",
            fieldType: "",
            hasParking: false,
            extraInfo: nil,
            rules: [],
            matchStatus: MatchStatus(backend: status),
            teamAScore: teamAScore,
            teamBScore: teamBScore,
            winnerTeam: winnerTeam,
            latitude: location?.latitude,
            longitude: location?.longitude
        )
    }
}

/// Location shape returned by the V2 feed — uses region *codes* (`cityCode`,
/// `countryCode`) rather than display names, so we surface the street `address`.
struct MatchLocationV2DTO: Decodable {
    let id: String?
    let address: String?
    let cityCode: String?
    let countryCode: String?
    let latitude: Double?
    let longitude: Double?

    static func displayString(_ location: MatchLocationV2DTO?) -> String {
        guard let loc = location else { return "" }
        if let address = loc.address, !address.isEmpty { return address }
        return [loc.cityCode, loc.countryCode].compactMap { $0 }.joined(separator: ", ")
    }
}

// MARK: - List Response

struct MatchListResponse: Decodable {
    let data: [MatchListItemDTO]
}

/// Image object returned by the production `/match/matches` endpoint.
struct FieldImageDTO: Decodable {
    let imagePath: String?
}

struct MatchListItemDTO: Decodable {
    let id: String
    let fieldName: String
    // Production endpoint: `fieldImages: [{ imagePath, ... }]`
    // Demo endpoint:       `fieldImages: []` (empty array of objects, no imagePath)
    // Both are optional so decoding succeeds for either format.
    private let fieldImageUrl: String?
    private let fieldImages: [FieldImageDTO]?
    var resolvedFieldImageUrl: String? { fieldImageUrl ?? fieldImages?.compactMap(\.imagePath).first }
    let startTime: Int64
    let endTime: Int64
    let originalPriceInCents: Int
    let totalDiscountInCents: Int
    let priceInCents: Int
    let genderType: String
    let status: String
    let availableSpots: Int
    let teams: MatchTeamsDTO
    let location: MatchLocationDTO?
    let teamAScore: Int?
    let teamBScore: Int?
    let winnerTeam: String?

    func toMatchItem() -> MatchItem {
        let (start, end) = MatchFormatters.dates(startMs: startTime, endMs: endTime)
        let totalPlayers = teams.teamA.players.count + teams.teamB.players.count
        let perTeamMax = max(1, (availableSpots + totalPlayers) / 2)
        return MatchItem(
            id: id,
            venueName: fieldName,
            location: MatchLocationDTO.displayString(location),
            timeRange: MatchFormatters.timeRange(start: start, end: end),
            date: MatchFormatters.dateString(start),
            startDate: start,
            price: MatchFormatters.priceString(priceInCents),
            matchType: MatchFormatters.genderLabel(genderType),
            spotsLeft: availableSpots,
            teamAPlayers: teams.teamA.players.map { $0.toMatchPlayer() },
            teamBPlayers: teams.teamB.players.map { $0.toMatchPlayer() },
            teamAMax: perTeamMax,
            teamBMax: perTeamMax,
            distance: "",
            duration: MatchFormatters.durationString(start: start, end: end),
            fieldImageUrl: resolvedFieldImageUrl,
            shoeType: "",
            fieldType: "",
            hasParking: false,
            extraInfo: nil,
            rules: [],
            matchStatus: MatchStatus(backend: status),
            teamAScore: teamAScore,
            teamBScore: teamBScore,
            winnerTeam: winnerTeam,
            latitude: location?.latitude,
            longitude: location?.longitude
        )
    }
}

// MARK: - Detail Response

struct MatchDetailResponse: Decodable {
    let data: MatchDetailItemDTO
}

struct MatchDetailItemDTO: Decodable {
    let id: String
    let fieldName: String
    private let fieldImageUrl: String?
    private let fieldImages: [FieldImageDTO]?
    var resolvedFieldImageUrl: String? { fieldImageUrl ?? fieldImages?.compactMap(\.imagePath).first }
    let startTime: Int64
    let endTime: Int64
    let originalPriceInCents: Int
    let totalDiscountInCents: Int
    let priceInCents: Int
    let genderType: String
    let status: String
    let availableSpots: Int
    /// Fixed total capacity. Optional because the detail endpoint may not send
    /// it yet; when present it is the source of truth for per-team capacity,
    /// matching the contract `MatchListItemV2DTO` already follows.
    let maxPlayers: Int?
    let teams: MatchTeamsDTO
    let location: MatchLocationDTO?
    let footwearType: String?
    let fieldType: String?
    let hasParking: Bool?
    let extraInfo: String?
    let description: String?
    let rules: String?
    let teamAScore: Int?
    let teamBScore: Int?
    let winnerTeam: String?
    let goalBreakdown: GoalBreakdownDTO?
    let bestPlayer: BestPlayerDTO?

    func toMatchItem() -> MatchItem {
        let (start, end) = MatchFormatters.dates(startMs: startTime, endMs: endTime)
        let totalPlayers = teams.teamA.players.count + teams.teamB.players.count
        // Prefer the fixed `maxPlayers` capacity; the `availableSpots + players`
        // fallback reconstructs it from a server counter that can drift from the
        // roster, and would then change `teamAMax` when moving list → detail.
        let perTeamMax = max(1, (maxPlayers ?? (availableSpots + totalPlayers)) / 2)
        return MatchItem(
            id: id,
            venueName: fieldName,
            location: MatchLocationDTO.displayString(location),
            timeRange: MatchFormatters.timeRange(start: start, end: end),
            date: MatchFormatters.dateString(start),
            startDate: start,
            price: MatchFormatters.priceString(priceInCents),
            matchType: MatchFormatters.genderLabel(genderType),
            spotsLeft: availableSpots,
            teamAPlayers: teams.teamA.players.map { $0.toMatchPlayer() },
            teamBPlayers: teams.teamB.players.map { $0.toMatchPlayer() },
            teamAMax: perTeamMax,
            teamBMax: perTeamMax,
            distance: "",
            duration: MatchFormatters.durationString(start: start, end: end),
            fieldImageUrl: resolvedFieldImageUrl,
            shoeType: footwearType ?? "",
            fieldType: fieldType ?? "",
            hasParking: hasParking ?? false,
            extraInfo: extraInfo,
            rules: rules?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? [],
            matchStatus: MatchStatus(backend: status),
            teamAScore: teamAScore,
            teamBScore: teamBScore,
            winnerTeam: winnerTeam,
            latitude: location?.latitude,
            longitude: location?.longitude,
            goalBreakdown: goalBreakdown?.toMatchGoalBreakdown(),
            bestPlayer: bestPlayer.map { MatchBestPlayer(userId: $0.userId, name: $0.name) }
        )
    }
}

// MARK: - Goal Breakdown / Best Player

struct GoalBreakdownDTO: Decodable {
    let teamA: TeamGoalBreakdownDTO
    let teamB: TeamGoalBreakdownDTO

    func toMatchGoalBreakdown() -> MatchGoalBreakdown {
        MatchGoalBreakdown(teamA: teamA.toMatchTeamGoalBreakdown(), teamB: teamB.toMatchTeamGoalBreakdown())
    }
}

struct TeamGoalBreakdownDTO: Decodable {
    let playerGoals: [PlayerGoalDTO]
    let externalGoals: Int

    func toMatchTeamGoalBreakdown() -> MatchTeamGoalBreakdown {
        MatchTeamGoalBreakdown(
            playerGoals: playerGoals.map { MatchPlayerGoal(id: $0.userId, name: $0.name, goals: $0.goals) },
            externalGoals: externalGoals
        )
    }
}

struct PlayerGoalDTO: Decodable {
    let name: String
    let userId: String
    let goals: Int
}

struct BestPlayerDTO: Decodable {
    let name: String
    let userId: String
}

// MARK: - Shared Sub-DTOs

struct MatchTeamsDTO: Decodable {
    let teamA: MatchTeamDTO
    let teamB: MatchTeamDTO
}

struct MatchTeamDTO: Decodable {
    let playerCount: Int
    let players: [MatchPlayerDTO]
}

struct MatchPlayerDTO: Decodable {
    let id: String
    let avatarUrl: String?
    let gender: String?
    let name: String
    let country: String?
    let status: String?   // optional: demo endpoints omit this field

    func toMatchPlayer() -> MatchPlayer {
        MatchPlayer(
            id: id,
            playerId: id,
            name: name,
            avatarUrl: avatarUrl,
            status: status?.uppercased() == "RESERVED" ? .reserved : .joined,
            country: country
        )
    }
}

struct MatchLocationDTO: Decodable {
    let id: String?
    let address: String?
    let city: String?
    let country: String?
    let countryCode: String?
    let cityCode: String?
    let latitude: Double?
    let longitude: Double?

    static func displayString(_ location: MatchLocationDTO?) -> String {
        guard let loc = location else { return "" }
        return loc.address ?? ""
    }
}

// MARK: - Formatters

enum MatchFormatters {
    static func dates(startMs: Int64, endMs: Int64) -> (Date, Date) {
        (
            Date(timeIntervalSince1970: Double(startMs) / 1000),
            Date(timeIntervalSince1970: Double(endMs) / 1000)
        )
    }

    static func timeRange(start: Date, end: Date) -> String {
        "\(timeLabel(start)) - \(timeLabel(end))"
    }

    static func timeLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "hh:mm a"
        return fmt.string(from: date)
    }

    static func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "EEE, d MMM"
        return fmt.string(from: date).capitalized
    }

    static func priceString(_ cents: Int) -> String {
        String(format: "$%.2f MXN", Double(cents) / 100.0)
    }

    /// Formats a kilometer distance using the device locale's decimal
    /// separator (e.g. "3,8 km" in Spanish, "3.8 km" in English).
    static func distanceString(_ km: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.locale = Locale.current
        let value = formatter.string(from: NSNumber(value: km)) ?? String(format: "%.1f", km)
        return "\(value) km"
    }

    static func durationString(start: Date, end: Date) -> String {
        "\(Int(end.timeIntervalSince(start) / 60)) min"
    }

    static func genderLabel(_ raw: String) -> String {
        switch raw.uppercased() {
        case "MIXED": return L10n.Matches.mixed
        case "MALE": return L10n.Matches.male
        case "FEMALE": return L10n.Matches.female
        default: return humanize(raw)
        }
    }

    /// Last-resort formatting for an unmapped backend enum value so a raw
    /// `SCREAMING_SNAKE_CASE` token never reaches the UI. Turns
    /// `"ARTIFICIAL_TURF"` into `"Artificial Turf"`.
    static func humanize(_ raw: String) -> String {
        raw
            .split(separator: "_")
            .map { $0.lowercased().capitalized }
            .joined(separator: " ")
    }
}

// MARK: - Join Match

struct JoinMatchRequest: Encodable {
    let team: String?
    let paymentProvider: String

    init(team: String? = nil, paymentProvider: String = "STRIPE") {
        self.team = team
        self.paymentProvider = paymentProvider
    }
}

struct JoinMatchResponse: Decodable {
    let data: JoinMatchData
}

struct JoinMatchData: Codable, Equatable {
    let clientSecret: String?
    let paymentId: String
    let provider: String
    let amountInCents: Int
    let currency: String
    let customer: String?
    let customerSessionClientSecret: String?
    let publishableKey: String?
    let reservationTtlMs: Int
    let reusedExistingPayment: Bool
    let existingPaymentStatus: String?
}

struct CancelMatchResponse: Decodable {
    let data: Bool
}

struct LeaveMatchResponse: Decodable {
    let data: Bool
}
