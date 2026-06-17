import Foundation

// MARK: - Shared date/price helpers (file-private)

private func adminMatchDateLabel(from date: Date) -> String {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
    let day = cal.startOfDay(for: date)

    if cal.isDate(day, inSameDayAs: today) { return "Hoy" }
    if cal.isDate(day, inSameDayAs: tomorrow) { return "Mañana" }

    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "es_MX")
    fmt.dateFormat = "EEE d"
    return fmt.string(from: date).capitalized
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
            status: AdminMatchStatus(rawValue: status) ?? .scheduled,
            fieldImageUrl: nil,
            startDate: startDate
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
            status: AdminMatchStatus(rawValue: status) ?? .scheduled,
            fieldImageUrl: primaryImage,
            startDate: startDate
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

// MARK: - Cancel Match (PATCH /match/admin/cancel/{matchId})

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
