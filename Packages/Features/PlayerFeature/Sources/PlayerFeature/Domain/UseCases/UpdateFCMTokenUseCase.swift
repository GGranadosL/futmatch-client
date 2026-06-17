import Foundation
import UIKit
import PersistenceFramework

// MARK: - Error

public enum DeviceError: LocalizedError {
    case missingDeviceId

    public var errorDescription: String? {
        switch self {
        case .missingDeviceId:
            return "No se encontró el identificador del dispositivo."
        }
    }
}

// MARK: - Protocol

public protocol UpdateFCMTokenUseCaseProtocol {
    func execute(fcmToken: String) async throws
}

// MARK: - Implementation

public final class UpdateFCMTokenUseCase: UpdateFCMTokenUseCaseProtocol {
    private let deviceService: DeviceServiceProtocol
    private let keychainManager: KeychainManaging

    public init(
        deviceService: DeviceServiceProtocol,
        keychainManager: KeychainManaging = KeychainManager.shared
    ) {
        self.deviceService = deviceService
        self.keychainManager = keychainManager
    }

    public func execute(fcmToken: String) async throws {
        guard let deviceId = try? keychainManager.retrieve(for: .deviceId), !deviceId.isEmpty else {
            throw DeviceError.missingDeviceId
        }

        let (deviceInfo, appVersion, osVersion) = await MainActor.run {
            let model = UIDevice.current.model
            let systemName = UIDevice.current.systemName
            let systemVersion = UIDevice.current.systemVersion
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            return ("\(model) / \(systemName) \(systemVersion)", version, systemVersion)
        }

        let request = UpdateFCMTokenRequest(
            deviceId: deviceId,
            platform: .ios,
            fcmToken: fcmToken,
            deviceInfo: deviceInfo,
            appVersion: appVersion,
            osVersion: osVersion
        )
        try await deviceService.updateFCMToken(request)
        try? keychainManager.save(fcmToken, for: .fcmToken)
    }
}
