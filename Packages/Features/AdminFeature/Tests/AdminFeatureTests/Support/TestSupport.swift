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
    static func stub(id: String = "field-1", name: String = "Cancha Central") -> FieldIdName {
        FieldIdName(id: id, name: name)
    }
}
