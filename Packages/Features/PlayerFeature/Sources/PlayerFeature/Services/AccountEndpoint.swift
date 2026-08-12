import Foundation
import NetworkFramework

// MARK: - AccountEndpoint

enum AccountEndpoint: APIEndpoint {
    /// Deactivates and anonymizes the authenticated account.
    case deleteAccount

    var path: String {
        switch self {
        case .deleteAccount: return "/user/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .deleteAccount: return .delete
        }
    }
}
