import Foundation
import CoreData
import NetworkFramework

// MARK: - Location Repository Implementation

final class LocationRepository: LocationRepositoryProtocol {
    private let apiClient: APIClient
    private let context: NSManagedObjectContext

    init(apiClient: APIClient = .shared, context: NSManagedObjectContext) {
        self.apiClient = apiClient
        self.context = context
    }

    // MARK: - Network Operations

    func fetchLocations() async throws -> [AdminLocation] {
        let response: LocationListResponse = try await apiClient.request(
            endpoint: LocationEndpoint.list
        )
        let locations = response.data.map { mapDTO($0) }
        try saveLocationsCache(locations)
        return locations
    }

    func getLocation(id: String) async throws -> AdminLocation {
        let response: LocationSingleResponse = try await apiClient.request(
            endpoint: LocationEndpoint.get(id: id)
        )
        return mapDTO(response.data)
    }

    func createLocation(request: CreateLocationRequest) async throws -> AdminLocation {
        let response: CreateLocationResponse = try await apiClient.request(
            endpoint: LocationEndpoint.create,
            body: request
        )

        let location = AdminLocation(
            id: response.data,
            address: request.address,
            country: request.countryCode,
            city: request.cityCode,
            latitude: request.latitude,
            longitude: request.longitude
        )

        // Cache it immediately (append — must not wipe other cached locations)
        try insertLocation(location)
        try context.save()

        return location
    }

    func updateLocation(request: UpdateLocationRequest) async throws -> AdminLocation {
        let _: LocationUpdateResponse = try await apiClient.request(
            endpoint: LocationEndpoint.update,
            body: request
        )

        let location = AdminLocation(
            id: request.id,
            address: request.address,
            country: request.countryCode,
            city: request.cityCode,
            latitude: request.latitude,
            longitude: request.longitude
        )

        // Update in cache
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "LocationEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", request.id)

        if let results = try? context.fetch(fetchRequest),
           let existing = results.first as? NSManagedObject {
            existing.setValue(request.address, forKey: "address")
            existing.setValue(request.countryCode, forKey: "country")
            existing.setValue(request.cityCode, forKey: "city")
            existing.setValue(request.latitude, forKey: "latitude")
            existing.setValue(request.longitude, forKey: "longitude")
            try? context.save()
        }

        return location
    }

    func deleteLocation(id: String) async throws {
        let _: LocationDeleteResponse = try await apiClient.request(
            endpoint: LocationEndpoint.delete(id: id)
        )

        // Remove from cache
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "LocationEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)

        if let results = try? context.fetch(fetchRequest) {
            for result in results {
                if let entity = result as? NSManagedObject {
                    context.delete(entity)
                }
            }
            try? context.save()
        }
    }

    // MARK: - Helpers

    private func mapDTO(_ dto: LocationResponseDTO) -> AdminLocation {
        AdminLocation(
            id: dto.id,
            address: dto.address,
            country: dto.countryCode,
            city: dto.cityCode,
            latitude: dto.latitude,
            longitude: dto.longitude
        )
    }

    // MARK: - CoreData Cache

    func saveLocationsCache(_ locations: [AdminLocation]) throws {
        // Clear existing cache
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "LocationEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try context.execute(deleteRequest)

        // Add new locations
        for location in locations {
            try insertLocation(location)
        }

        try context.save()
    }

    /// Inserts a single location into the managed object context without saving.
    /// Callers are responsible for calling `context.save()`.
    private func insertLocation(_ location: AdminLocation) throws {
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "LocationEntity", in: context) else {
            throw NSError(domain: "LocationRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find LocationEntity in data model"])
        }

        let entity = NSManagedObject(entity: entityDescription, insertInto: context)
        entity.setValue(location.id, forKey: "id")
        entity.setValue(location.address, forKey: "address")
        entity.setValue(location.country, forKey: "country")
        entity.setValue(location.city, forKey: "city")
        entity.setValue(location.latitude, forKey: "latitude")
        entity.setValue(location.longitude, forKey: "longitude")
        entity.setValue(Date(), forKey: "createdAt")
    }

    func loadLocationsCache() -> [AdminLocation] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "LocationEntity")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        guard let results = try? context.fetch(fetchRequest) else {
            return []
        }
        return results.compactMap { result in
            guard let entity = result as? NSManagedObject else { return nil }

            let id = (entity.value(forKey: "id") as? String) ?? UUID().uuidString
            let address = (entity.value(forKey: "address") as? String) ?? ""
            let country = (entity.value(forKey: "country") as? String) ?? "MX"
            let city = (entity.value(forKey: "city") as? String) ?? "MX_CDMX"
            let latitude = (entity.value(forKey: "latitude") as? Double) ?? 0.0
            let longitude = (entity.value(forKey: "longitude") as? Double) ?? 0.0

            return AdminLocation(
                id: id,
                address: address,
                country: country,
                city: city,
                latitude: latitude,
                longitude: longitude
            )
        }
    }
}

// MARK: - Note
// LocationEntity is generated automatically by CoreData from the .xcdatamodel file.
// Do NOT define it here manually to avoid duplicate symbol errors.
// Just reference it as: (result as? LocationEntity)
