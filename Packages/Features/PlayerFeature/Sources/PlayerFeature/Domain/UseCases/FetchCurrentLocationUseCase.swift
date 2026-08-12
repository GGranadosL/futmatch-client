import Foundation

// MARK: - Protocol

protocol FetchCurrentLocationUseCaseProtocol {
    /// Resolves the device's current coordinate, prompting for When-In-Use
    /// permission if not yet determined. Nil when denied, unavailable, or timed out.
    func execute() async -> (latitude: Double, longitude: Double)?
}

// MARK: - Implementation

struct FetchCurrentLocationUseCase: FetchCurrentLocationUseCaseProtocol {
    private let repository: DeviceLocationRepositoryProtocol

    init(repository: DeviceLocationRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async -> (latitude: Double, longitude: Double)? {
        await repository.fetchCurrentCoordinate()
    }
}
