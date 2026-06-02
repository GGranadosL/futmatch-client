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
    private let keychainManager: KeychainManager

    public init(
        deviceService: DeviceServiceProtocol,
        keychainManager: KeychainManager = .shared
    ) {
        self.deviceService = deviceService
        self.keychainManager = keychainManager
    }

    public func execute(fcmToken: String) async throws {
        guard let deviceId = try? keychainManager.retrieve(for: .deviceId), !deviceId.isEmpty else {
#if DEBUG
            print("[FCM] No deviceId found in Keychain, cannot sync FCM token")
#endif
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
#if DEBUG
        print("[FCM] Sending FCM token to backend: deviceId=\(deviceId), fcmToken=\(fcmToken)")
#endif
        try await deviceService.updateFCMToken(request)
#if DEBUG
        print("[FCM] FCM token successfully sent to backend")
#endif
        try? keychainManager.save(fcmToken, for: .fcmToken)
    }
}
