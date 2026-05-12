import Foundation
import NetworkFramework

// MARK: - DeviceEndpoint

enum DeviceEndpoint: APIEndpoint {
    case updateFCMToken(UpdateFCMTokenRequest)

    // MARK: APIEndpoint

    var path: String {
        switch self {
        case .updateFCMToken:
            return "/device/fcm-token"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .updateFCMToken:
            return .put
        }
    }

    var body: Data? {
        switch self {
        case .updateFCMToken(let request):
            return try? JSONEncoder().encode(request)
        }
    }
}
