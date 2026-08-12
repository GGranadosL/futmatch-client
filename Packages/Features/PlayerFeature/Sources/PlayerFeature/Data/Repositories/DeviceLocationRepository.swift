import Foundation

// MARK: - Device Location Repository

struct DeviceLocationRepository: DeviceLocationRepositoryProtocol {
    private let locationService: CurrentLocationProviding

    init(locationService: CurrentLocationProviding) {
        self.locationService = locationService
    }

    func fetchCurrentCoordinate() async -> (latitude: Double, longitude: Double)? {
        guard let coordinate = await locationService.requestCurrentLocation() else { return nil }
        return (coordinate.latitude, coordinate.longitude)
    }
}
