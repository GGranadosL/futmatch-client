import Foundation
@testable import AdminFeature

// MARK: - Shared test error

/// Generic error used by mocks to exercise failure/propagation paths.
enum TestError: Error, Equatable {
    case boom
}

// MARK: - Domain model stubs
//
// Minimal builders so tests read intent-first ("given a field…") instead of
// repeating every field. Override only what a test cares about.

extension CreateFieldParams {
    static func stub(
        name: String = "Cancha Central",
        priceInCents: Int = 50_000,
        capacity: Int = 10,
        description: String = "Una cancha",
        rules: String = "1. Sin tachones",
        footwearType: FootwearType? = nil,
        fieldType: FieldType? = nil,
        hasParking: Bool = false,
        extraInfo: String? = nil
    ) -> CreateFieldParams {
        CreateFieldParams(
            name: name,
            priceInCents: priceInCents,
            capacity: capacity,
            description: description,
            rules: rules,
            footwearType: footwearType,
            fieldType: fieldType,
            hasParking: hasParking,
            extraInfo: extraInfo
        )
    }
}

extension Field {
    static func stub(
        id: String = "field-1",
        name: String = "Cancha Central",
        priceInCents: Int = 50_000,
        capacity: Int = 10,
        description: String = "Una cancha",
        rules: String = "1. Sin tachones",
        footwearType: FootwearType? = nil,
        fieldType: FieldType? = nil,
        hasParking: Bool = false,
        extraInfo: String? = nil
    ) -> Field {
        Field(
            id: id,
            name: name,
            priceInCents: priceInCents,
            capacity: capacity,
            description: description,
            rules: rules,
            footwearType: footwearType,
            fieldType: fieldType,
            hasParking: hasParking,
            extraInfo: extraInfo
        )
    }
}

extension AdminFieldItem {
    static func stub(
        id: String = "field-1",
        name: String = "Cancha Central",
        priceInCents: Int = 50_000,
        capacity: Int = 10
    ) -> AdminFieldItem {
        AdminFieldItem(
            id: id,
            name: name,
            priceInCents: priceInCents,
            capacity: capacity
        )
    }
}

extension AdminDashboard {
    static func stub(
        scheduledMatchesCount: Int = 3,
        registeredVenuesCount: Int = 2,
        upcomingMatches: [AdminUpcomingMatch] = []
    ) -> AdminDashboard {
        AdminDashboard(
            scheduledMatchesCount: scheduledMatchesCount,
            registeredVenuesCount: registeredVenuesCount,
            upcomingMatches: upcomingMatches
        )
    }
}

extension FieldIdName {
    static func stub(
        id: String = "field-1",
        name: String = "Cancha Central",
        priceInCents: Int = 50_000,
        maxPlayersAllowed: Int = 14
    ) -> FieldIdName {
        FieldIdName(id: id, name: name, priceInCents: priceInCents, maxPlayersAllowed: maxPlayersAllowed)
    }
}

extension AdminMatch {
    static func stub(
        id: String = "match-1",
        fieldName: String = "Cancha Central",
        status: AdminMatchStatus = .scheduled,
        startDate: Date = Date()
    ) -> AdminMatch {
        AdminMatch(
            id: id,
            fieldName: fieldName,
            dateLabel: "Hoy",
            timeRange: "20:00 – 22:00",
            price: "$150.00",
            gender: .mixed,
            playerLevel: .any,
            spotsFilled: 0,
            spotsTotal: 10,
            status: status,
            fieldImageUrl: nil,
            startDate: startDate,
            fieldId: "field-1",
            endDate: startDate.addingTimeInterval(7200),
            minPlayers: 6
        )
    }
}

extension AdminMatchPlayer {
    static func stub(
        id: String = "p-1",
        name: String = "Jugador",
        team: String = "A"
    ) -> AdminMatchPlayer {
        AdminMatchPlayer(id: id, playerId: id, name: name)
    }
}
