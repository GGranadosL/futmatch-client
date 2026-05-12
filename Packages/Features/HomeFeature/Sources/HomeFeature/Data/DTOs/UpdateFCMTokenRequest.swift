import Foundation

// MARK: - Platform

public enum DevicePlatform: String, Encodable {
    case ios = "IOS"
    case android = "ANDROID"
}

// MARK: - Request DTO

public struct UpdateFCMTokenRequest: Encodable {
    public let deviceId: String
    public let platform: DevicePlatform
    public let fcmToken: String
    public let deviceInfo: String
    public let appVersion: String
    public let osVersion: String

    public init(
        deviceId: String,
        platform: DevicePlatform = .ios,
        fcmToken: String,
        deviceInfo: String,
        appVersion: String,
        osVersion: String
    ) {
        self.deviceId = deviceId
        self.platform = platform
        self.fcmToken = fcmToken
        self.deviceInfo = deviceInfo
        self.appVersion = appVersion
        self.osVersion = osVersion
    }
}

// MARK: - Response DTO

struct UpdateFCMTokenResponse: Decodable {
    let data: ResponseData

    struct ResponseData: Decodable {
        let success: Bool
        let message: String
    }
}
