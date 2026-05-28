import Foundation

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
            fieldImageName: resolvedFieldImageUrl,
            shoeType: "",
            fieldType: "",
            hasParking: false,
            extraInfo: nil,
            rules: [],
            matchStatus: status,
            teamAScore: teamAScore,
            teamBScore: teamBScore,
            winnerTeam: winnerTeam
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
            fieldImageName: resolvedFieldImageUrl,
            shoeType: Self.mapFootwear(footwearType),
            fieldType: Self.mapFieldType(fieldType),
            hasParking: hasParking ?? false,
            extraInfo: extraInfo,
            rules: rules?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? [],
            matchStatus: status,
            teamAScore: teamAScore,
            teamBScore: teamBScore,
            winnerTeam: winnerTeam
        )
    }

    private static func mapFootwear(_ raw: String?) -> String {
        switch raw?.uppercased() {
        case "TURF": return "Tacos para pasto sintético"
        case "RUBBER": return "Tenis de hule"
        default: return raw ?? ""
        }
    }

    private static func mapFieldType(_ raw: String?) -> String {
        switch raw?.uppercased() {
        case "SYNTHETIC": return "Pasto sintético"
        case "NATURAL": return "Pasto natural"
        default: return raw ?? ""
        }
    }
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
    let latitude: Double?
    let longitude: Double?

    static func displayString(_ location: MatchLocationDTO?) -> String {
        guard let loc = location else { return "" }
        return [loc.city, loc.country].compactMap { $0 }.joined(separator: ", ")
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
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "hh:mm a"
        return "\(fmt.string(from: start)) - \(fmt.string(from: end))"
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

    static func durationString(start: Date, end: Date) -> String {
        "\(Int(end.timeIntervalSince(start) / 60)) min"
    }

    static func genderLabel(_ raw: String) -> String {
        switch raw.uppercased() {
        case "MIXED": return L10n.Matches.mixed
        case "MALE": return "Varonil"
        case "FEMALE": return "Femenil"
        default: return raw
        }
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
    let clientSecret: String
    let paymentId: String
    let provider: String
    let amountInCents: Int
    let currency: String
    let customer: String
    let customerSessionClientSecret: String
    let publishableKey: String
    let reservationTtlMs: Int
}

struct CancelMatchResponse: Decodable {
    let data: Bool
}

struct LeaveMatchResponse: Decodable {
    let data: Bool
}
