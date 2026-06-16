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

        try await context.perform {
            let entity = LocationEntity(context: self.context)
            entity.id = location.id
            entity.address = location.address
            entity.country = location.country
            entity.city = location.city
            entity.latitude = location.latitude
            entity.longitude = location.longitude
            entity.createdAt = Date()
            if self.context.hasChanges { try self.context.save() }
        }

        return location
    }

    func updateLocation(request: UpdateLocationRequest) async throws -> AdminLocation {
        let _: EmptyResponse = try await apiClient.request(
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

        try await context.perform {
            let fetchRequest = LocationEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", request.id)
            if let entity = try self.context.fetch(fetchRequest).first {
                entity.address = request.address
                entity.country = request.countryCode
                entity.city = request.cityCode
                entity.latitude = request.latitude
                entity.longitude = request.longitude
                if self.context.hasChanges { try self.context.save() }
            }
        }

        return location
    }

    func deleteLocation(id: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            endpoint: LocationEndpoint.delete(id: id)
        )

        try await context.perform {
            let fetchRequest = LocationEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            let results = try self.context.fetch(fetchRequest)
            results.forEach { self.context.delete($0) }
            if self.context.hasChanges { try self.context.save() }
        }
    }

    // MARK: - CoreData Cache

    func saveLocationsCache(_ locations: [AdminLocation]) throws {
        try context.performAndWait {
            let existing = try self.context.fetch(LocationEntity.fetchRequest())
            existing.forEach { self.context.delete($0) }
            for location in locations {
                let entity = LocationEntity(context: self.context)
                entity.id = location.id
                entity.address = location.address
                entity.country = location.country
                entity.city = location.city
                entity.latitude = location.latitude
                entity.longitude = location.longitude
                entity.createdAt = Date()
            }
            if self.context.hasChanges { try self.context.save() }
        }
    }

    func loadLocationsCache() -> [AdminLocation] {
        context.performAndWait {
            let fetchRequest = LocationEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            guard let results = try? self.context.fetch(fetchRequest) else { return [] }
            return results.compactMap { entity in
                guard let id = entity.id, let address = entity.address,
                      let country = entity.country, let city = entity.city else { return nil }
                return AdminLocation(
                    id: id,
                    address: address,
                    country: country,
                    city: city,
                    latitude: entity.latitude,
                    longitude: entity.longitude
                )
            }
        }
    }

    // MARK: - Private

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
}
