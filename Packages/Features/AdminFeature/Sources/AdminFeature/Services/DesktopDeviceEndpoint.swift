import Foundation
import NetworkFramework

// MARK: - DesktopDeviceEndpoint

/// Admin-side endpoints for approving a Futmatch Desktop installation. Both sit
/// behind the backend's auth-jwt and App Check guards; the bearer token and the
/// `X-Firebase-AppCheck` header come from the shared `APIClient` interceptors.
enum DesktopDeviceEndpoint: APIEndpoint {
    /// `POST /admin/desktop-devices/enrollment-details`
    case enrollmentDetails
    /// `POST /admin/desktop-devices/approve-enrollment`
    case approveEnrollment

    var path: String {
        switch self {
        case .enrollmentDetails:
            return "/admin/desktop-devices/enrollment-details"
        case .approveEnrollment:
            return "/admin/desktop-devices/approve-enrollment"
        }
    }

    var method: HTTPMethod { .post }
}
