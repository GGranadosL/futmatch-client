import Foundation

// MARK: - Create Location

struct CreateLocationRequest: Encodable {
    let address: String
    let countryCode: String
    let cityCode: String
    let latitude: Double
    let longitude: Double
}

struct CreateLocationResponse: Decodable {
    let data: String  // UUID of the created location
}

// MARK: - Update Location

struct UpdateLocationRequest: Encodable {
    let id: String
    let address: String
    let countryCode: String
    let cityCode: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Get / List Location Response

struct LocationResponseDTO: Decodable {
    let id: String
    let address: String
    let countryCode: String
    let cityCode: String
    let latitude: Double
    let longitude: Double
}

struct LocationSingleResponse: Decodable {
    let data: LocationResponseDTO
}

struct LocationListResponse: Decodable {
    let data: [LocationResponseDTO]
}

// MARK: - Location Domain Model

public struct AdminLocation: Identifiable, Equatable {
    public let id: String
    let address: String
    /// Country code (e.g. "MX"). Client-localized for display.
    let country: String
    /// City code (e.g. "MX_CDMX"). Client-localized for display.
    let city: String
    let latitude: Double
    let longitude: Double

    init(id: String, address: String, country: String, city: String, latitude: Double, longitude: Double) {
        self.id = id
        self.address = address
        self.country = country
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
    }
}

