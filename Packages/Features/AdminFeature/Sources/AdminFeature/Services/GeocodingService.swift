import Foundation

// MARK: - Geocoding Service Protocol

public protocol GeocodingServiceProtocol {
    /// Reverse geocode coordinates to get address
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> String

    /// Search for addresses matching a query
    func searchAddresses(query: String) async throws -> [GeocodingSearchResult]
}

// MARK: - Nominatim Models

public struct GeocodingSearchResult: Identifiable, Equatable, Decodable {
    public let id: Int
    public let name: String
    public let address: String
    public let latitude: Double
    public let longitude: Double

    enum CodingKeys: String, CodingKey {
        case id = "osm_id"
        case name = "display_name"
        case address = "address"
        case latitude = "lat"
        case longitude = "lon"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        latitude = try Double(container.decode(String.self, forKey: .latitude)) ?? 0
        longitude = try Double(container.decode(String.self, forKey: .longitude)) ?? 0
    }
}

private struct NominatimReverseGeocodeResponse: Decodable {
    let address: AddressComponents?

    struct AddressComponents: Decodable {
        let road: String?
        let neighborhood: String?
        let suburb: String?
        let city: String?
        let county: String?
        let state: String?
        let postcode: String?
        let country: String?
        let country_code: String?

        var formattedAddress: String {
            [road, neighborhood ?? suburb, city].compactMap { $0 }.joined(separator: ", ")
        }
    }
}

// MARK: - Nominatim Implementation

public final class NominatimGeocodingService: GeocodingServiceProtocol {
    private let baseURL = "https://nominatim.openstreetmap.org"
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Reverse geocode coordinates to get address
    /// - Parameters:
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: Formatted address string
    public func reverseGeocode(latitude: Double, longitude: Double) async throws -> String {
        let urlString = "\(baseURL)/reverse?format=json&lat=\(latitude)&lon=\(longitude)&zoom=18&addressdetails=1&accept-language=es"
        guard let url = URL(string: urlString) else {
            throw GeocodingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("FutMatch-Admin/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw GeocodingError.serverError
        }

        let result = try JSONDecoder().decode(NominatimReverseGeocodeResponse.self, from: data)

        // Try to get a formatted address from components
        if let address = result.address?.formattedAddress, !address.isEmpty {
            return address
        }

        // Fallback to display_name or coordinates
        return "Lat: \(latitude), Lon: \(longitude)"
    }

    /// Search for addresses matching a query
    /// - Parameter query: Search query string
    /// - Returns: Array of search results with coordinates
    public func searchAddresses(query: String) async throws -> [GeocodingSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw GeocodingError.invalidURL
        }

        let urlString = "\(baseURL)/search?format=json&q=\(encodedQuery)&limit=10&countrycodes=mx&accept-language=es"
        guard let url = URL(string: urlString) else {
            throw GeocodingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("FutMatch-Admin/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw GeocodingError.serverError
        }

        // Nominatim's /search returns a top-level JSON array, not a wrapper object.
        return try JSONDecoder().decode([GeocodingSearchResult].self, from: data)
    }
}

// MARK: - Errors

enum GeocodingError: LocalizedError {
    case invalidURL
    case serverError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .serverError:
            return "Error del servidor de geocoding"
        case .decodingError:
            return "Error al procesar la respuesta"
        }
    }
}
