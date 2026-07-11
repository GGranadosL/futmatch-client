import Foundation

// MARK: - Shared date/price helpers (file-private)

private func adminMatchDateLabel(from date: Date) -> String {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
    let day = cal.startOfDay(for: date)

    if cal.isDate(day, inSameDayAs: today) { return L10n.AdminMatches.sectionToday }
    if cal.isDate(day, inSameDayAs: tomorrow) { return L10n.AdminMatches.sectionTomorrow }

    let fmt = DateFormatter()
    fmt.setLocalizedDateFormatFromTemplate("EEEdMMMM")
    let label = fmt.string(from: date)
    return label.prefix(1).localizedUppercase + label.dropFirst()
}

private func adminMatchTimeRange(from start: Date, to end: Date) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "HH:mm"
    return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
}

private func adminMatchFormatPrice(_ cents: Int64) -> String {
    String(format: "$%.2f", Double(cents) / 100.0)
}

// Combines a calendar date + a time-of-day date into an epoch-millisecond timestamp.
private func combinedEpochMs(date: Date, time: Date) -> Int64 {
    let cal = Calendar.current
    var dc = cal.dateComponents([.year, .month, .day], from: date)
    let tc = cal.dateComponents([.hour, .minute], from: time)
    dc.hour = tc.hour
    dc.minute = tc.minute
    dc.second = 0
    return Int64((cal.date(from: dc) ?? date).timeIntervalSince1970 * 1000)
}

// MARK: - Create Match

struct CreateMatchRequestDTO: Encodable {
    let fieldId: String
    let supervisorId: String?
    let dateTime: Int64
    let dateTimeEnd: Int64
    let maxPlayers: Int
    let minPlayersRequired: Int
    let matchPriceInCents: Int64
    let discountIds: [String]
    let status: String
    let genderType: String
    let playerLevel: String

    static func from(_ params: CreateMatchParams) -> CreateMatchRequestDTO {
        CreateMatchRequestDTO(
            fieldId: params.fieldId,
            supervisorId: nil,
            dateTime: combinedEpochMs(date: params.date, time: params.startTime),
            dateTimeEnd: combinedEpochMs(date: params.date, time: params.endTime),
            maxPlayers: params.maxPlayers,
            minPlayersRequired: params.minPlayers,
            matchPriceInCents: Int64(params.priceInCents),
            discountIds: [],
            status: "SCHEDULED",
            genderType: params.gender.rawValue,
            playerLevel: params.playerLevel.rawValue
        )
    }
}

struct CreateMatchResponseDTO: Decodable {
    let data: CreateMatchResponseDataDTO
}

struct CreateMatchResponseDataDTO: Decodable {
    let id: String
    let fieldId: String
    let supervisorId: String?
    let dateTime: Int64
    let dateTimeEnd: Int64
    let maxPlayers: Int
    let minPlayersRequired: Int
    let matchPriceInCents: Int64
    let discountPriceInCents: Int64
    let status: String
    let genderType: String
    let playerLevel: String

    func toDomain(fieldName: String) -> AdminMatch {
        let startDate = Date(timeIntervalSince1970: Double(dateTime) / 1000.0)
        let endDate   = Date(timeIntervalSince1970: Double(dateTimeEnd) / 1000.0)

        return AdminMatch(
            id: id,
            fieldName: fieldName,
            dateLabel: adminMatchDateLabel(from: startDate),
            timeRange: adminMatchTimeRange(from: startDate, to: endDate),
            price: adminMatchFormatPrice(matchPriceInCents),
            gender: genderFromBackend(genderType),
            playerLevel: MatchPlayerLevel(rawValue: playerLevel) ?? .any,
            spotsFilled: 0,
            spotsTotal: maxPlayers,
            status: AdminMatchStatus(backend: status),
            fieldImageUrl: nil,
            startDate: startDate,
            fieldId: fieldId,
            endDate: endDate,
            minPlayers: minPlayersRequired
        )
    }
}

// MARK: - Match List (GET /match/admin/matches and /match/admin/matches/{fieldId})

struct AdminMatchListResponseDTO: Decodable {
    let data: [AdminMatchListItemDTO]
}

struct AdminMatchListItemDTO: Decodable {
    let matchId: String
    let fieldId: String
    let fieldName: String
    let fieldLocation: AdminMatchLocationDTO?
    let matchDateTime: Int64
    let matchDateTimeEnd: Int64
    let matchPriceInCents: Int64
    let discountInCents: Int64
    let maxPlayers: Int
    let enrolledPlayers: Int
    let minPlayersRequired: Int
    let status: String
    let footwearType: String?
    let fieldType: String?
    let hasParking: Bool?
    let fieldImages: [AdminMatchFieldImageDTO]
    let genderType: String
    let playerLevel: String

    func toDomain() -> AdminMatch {
        let startDate = Date(timeIntervalSince1970: Double(matchDateTime) / 1000.0)
        let endDate   = Date(timeIntervalSince1970: Double(matchDateTimeEnd) / 1000.0)
        let primaryImage = fieldImages.first(where: { $0.position == 0 })?.imagePath

        return AdminMatch(
            id: matchId,
            fieldName: fieldName,
            dateLabel: adminMatchDateLabel(from: startDate),
            timeRange: adminMatchTimeRange(from: startDate, to: endDate),
            price: adminMatchFormatPrice(matchPriceInCents),
            gender: genderFromBackend(genderType),
            playerLevel: MatchPlayerLevel(rawValue: playerLevel) ?? .any,
            spotsFilled: enrolledPlayers,
            spotsTotal: maxPlayers,
            status: AdminMatchStatus(backend: status),
            fieldImageUrl: primaryImage,
            startDate: startDate,
            fieldId: fieldId,
            endDate: endDate,
            minPlayers: minPlayersRequired,
            address: fieldLocation?.address,
            latitude: fieldLocation?.latitude,
            longitude: fieldLocation?.longitude
        )
    }
}

struct AdminMatchLocationDTO: Decodable {
    let id: String
    let address: String
    let cityCode: String
    let countryCode: String
    let latitude: Double?
    let longitude: Double?
}

struct AdminMatchFieldImageDTO: Decodable {
    let id: String
    let fieldId: String
    let imagePath: String
    let position: Int
}

// MARK: - Update Match (PUT /match/admin/update/{matchId})

struct UpdateMatchRequestDTO: Encodable {
    let fieldId: String
    let supervisorId: String?
    let dateTime: Int64
    let dateTimeEnd: Int64
    let maxPlayers: Int
    let minPlayersRequired: Int
    let matchPriceInCents: Int64
    let discountIds: [String]
    let status: String
    let genderType: String
    let playerLevel: String

    static func from(_ params: UpdateMatchParams) -> UpdateMatchRequestDTO {
        UpdateMatchRequestDTO(
            fieldId: params.fieldId,
            supervisorId: nil,
            dateTime: combinedEpochMs(date: params.date, time: params.startTime),
            dateTimeEnd: combinedEpochMs(date: params.date, time: params.endTime),
            maxPlayers: params.maxPlayers,
            minPlayersRequired: params.minPlayers,
            matchPriceInCents: Int64(params.priceInCents),
            discountIds: [],
            status: "SCHEDULED",
            genderType: params.gender.rawValue,
            playerLevel: params.playerLevel.rawValue
        )
    }
}

// MARK: - Cancel Match (PATCH /match/admin/cancel/{matchId})

struct CancelMatchRequestDTO: Encodable {
    let reason: String
}

struct CancelMatchResponseDTO: Decodable {
    let data: CancelMatchDataDTO
}

struct CancelMatchDataDTO: Decodable {
    let canceled: Bool
    let totalPlayers: Int
    let playersRemoved: Int
    let paymentsCancelled: Int
    let refundsIssued: Int
}

// MARK: - Complete Match (POST /match/admin/{matchId}/complete)

struct CompleteMatchRequestDTO: Encodable {
    struct GoalDTO: Encodable {
        let userId: String
        let goals: Int
    }
    struct ExternalGoalDTO: Encodable {
        let team: String
        let goals: Int
    }
    let goals: [GoalDTO]
    let externalGoals: [ExternalGoalDTO]
    let bestPlayerId: String
}

struct CompleteMatchResponseDTO: Decodable {
    let data: Bool?
}

// MARK: - Rebalance Teams (POST /match/admin/{matchId}/rebalance-teams)

struct PlayerTeamAssignmentDTO: Encodable {
    let userId: String
    let team: String
}

struct RebalanceTeamsRequestDTO: Encodable {
    let players: [PlayerTeamAssignmentDTO]
}

struct RebalanceTeamsResponseDTO: Decodable {
    let data: Bool
}

// MARK: - Match Detail (GET /match/{matchId})

struct AdminMatchDetailResponseDTO: Decodable {
    let data: AdminMatchDetailItemDTO
}

struct AdminMatchDetailItemDTO: Decodable {
    let teams: AdminMatchTeamsDTO
}

struct AdminMatchTeamsDTO: Decodable {
    let teamA: AdminMatchTeamDTO
    let teamB: AdminMatchTeamDTO
}

struct AdminMatchTeamDTO: Decodable {
    let players: [AdminMatchPlayerDTO]
}

struct AdminMatchPlayerDTO: Decodable {
    let id: String
    let name: String
    let avatarUrl: String?
    let country: String?
    let status: String?

    func toAdminMatchPlayer() -> AdminMatchPlayer {
        let playerStatus: AdminMatchPlayer.Status = (status?.uppercased() == "RESERVED") ? .reserved : .joined
        return AdminMatchPlayer(
            id: id,
            playerId: id,
            name: name,
            avatarUrl: avatarUrl,
            status: playerStatus,
            country: country,
            isExternal: false
        )
    }
}
