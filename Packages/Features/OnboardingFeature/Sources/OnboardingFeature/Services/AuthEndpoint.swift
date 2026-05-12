import Foundation
import NetworkFramework

enum AuthEndpoint: APIEndpoint {
    
    case registerStart(RegisterStartRequest)
    case registerComplete(RegisterCompleteRequest)
    case registerResendCode(ResendRegistrationCodeRequest)
    case signIn(SignInRequest)
    case mfaSend(MFASendRequest)
    case mfaVerify(MFAVerifyRequest)
    case forgotPassword(email: String)
    case verifyResetMFA(VerifyResetMFARequest)
    case resetPassword(ResetPasswordRequest, resetToken: String)
    case refreshToken(RefreshTokenRequest)
    case signOut(deviceId: String)
    
    var path: String {
        switch self {
        case .registerStart:
            return "/auth/register/start"   
        case .registerComplete:
            return "/auth/register/complete"
        case .registerResendCode:
            return "/auth/register/resend-code"
        case .signIn:
            return "/auth/signIn"
        case .mfaSend:
            return "/auth/mfa/send"
        case .mfaVerify:
            return "/auth/mfa/verify"
        case .forgotPassword:
            return "/auth/forgot-password"
        case .verifyResetMFA:
            return "/auth/verify-reset-mfa"
        case .resetPassword:
            return "/auth/password"
        case .refreshToken:
            return "/auth/refresh"
        case .signOut:
            return "/auth/signOut"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .registerStart, .registerComplete, .registerResendCode, .signIn, .mfaSend, .mfaVerify, .forgotPassword, .verifyResetMFA, .refreshToken, .signOut:
            return .post
        case .resetPassword:
            return .put
        }
    }
    
    var queryItems: [URLQueryItem]? {
        return nil
    }
    
    var headers: [String: String] {
        var headers = ["Content-Type": "application/json"]
        
        switch self {
        case .resetPassword(_, let resetToken):
            headers["Authorization"] = "Bearer \(resetToken)"
        case .refreshToken(let request):
            headers["x-refresh-token"] = request.refreshToken
        default:
            break
        }
        
        return headers
    }
    
    var body: Data? {
        switch self {
        case .registerStart(let request):
            return try? JSONEncoder().encode(request)
        case .registerComplete(let request):
            return try? JSONEncoder().encode(request)
        case .registerResendCode(let request):
            return try? JSONEncoder().encode(request)
        case .signIn(let request):
            return try? JSONEncoder().encode(request)
        case .mfaSend(let request):
            return try? JSONEncoder().encode(request)
        case .mfaVerify(let request):
            return try? JSONEncoder().encode(request)
        case .forgotPassword(let email):
            let request = ["email": email]
            return try? JSONEncoder().encode(request)
        case .verifyResetMFA(let request):
            return try? JSONEncoder().encode(request)
        case .resetPassword(let request, _):
            return try? JSONEncoder().encode(request)
        case .refreshToken(let request):
            // Only userId and deviceId in body; refreshToken goes in x-refresh-token header
            let bodyPayload = ["userId": request.userId, "deviceId": request.deviceId]
            return try? JSONEncoder().encode(bodyPayload)
        case .signOut(let deviceId):
            let signOutRequest = ["deviceId": deviceId]
            return try? JSONEncoder().encode(signOutRequest)
        }
    }
    
    var requiresAuth: Bool {
        switch self {
        case .refreshToken, .registerStart, .registerComplete, .registerResendCode, .signIn, .mfaSend, .mfaVerify, .forgotPassword, .verifyResetMFA, .resetPassword:
            return false
        case .signOut:
            return true
        }
    }
    
    var timeout: TimeInterval {
        return 30
    }
}
