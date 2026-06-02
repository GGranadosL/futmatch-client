import Foundation
import NetworkFramework

// MARK: - Protocol

public protocol DeviceServiceProtocol {
    func updateFCMToken(_ request: UpdateFCMTokenRequest) async throws
}

// MARK: - Implementation

public final class DeviceService: DeviceServiceProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    public func updateFCMToken(_ request: UpdateFCMTokenRequest) async throws {
        let endpoint = DeviceEndpoint.updateFCMToken(request)
        let _: UpdateFCMTokenResponse = try await apiClient.request(endpoint: endpoint)
    }
}
