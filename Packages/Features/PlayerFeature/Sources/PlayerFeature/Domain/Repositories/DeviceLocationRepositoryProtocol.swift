import Foundation

// MARK: - Device Location Repository Protocol

/// Abstracts the device's current GPS coordinate away from the underlying
/// CoreLocation service, matching the mandatory Repository/UseCase chain.
protocol DeviceLocationRepositoryProtocol {
    func fetchCurrentCoordinate() async -> (latitude: Double, longitude: Double)?
}
