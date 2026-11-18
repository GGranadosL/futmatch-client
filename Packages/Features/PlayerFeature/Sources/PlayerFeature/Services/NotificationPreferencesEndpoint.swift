import Foundation
import NetworkFramework

// MARK: - NotificationPreferencesEndpoint

enum NotificationPreferencesEndpoint: APIEndpoint {
    /// `GET /user` — carries `matchInviteNotificationsEnabled`.
    case current
    /// `PATCH /user/notification-preferences`.
    case update

    var path: String {
        switch self {
        case .current: return "/user"
        case .update:  return "/user/notification-preferences"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .current: return .get
        case .update:  return .patch
        }
    }
}
