import Foundation

// MARK: - Location Repository Protocol

protocol LocationRepositoryProtocol {
    /// Fetch all locations from the API and update the local cache.
    func fetchLocations() async throws -> [AdminLocation]

    /// Get a single location by ID.
    func getLocation(id: String) async throws -> AdminLocation

    /// Create a new location
    func createLocation(request: CreateLocationRequest) async throws -> AdminLocation

    /// Update an existing location
    func updateLocation(request: UpdateLocationRequest) async throws -> AdminLocation

    /// Delete a location
    func deleteLocation(id: String) async throws

    /// Cache locations locally
    func saveLocationsCache(_ locations: [AdminLocation]) throws

    /// Load cached locations
    func loadLocationsCache() -> [AdminLocation]
}
