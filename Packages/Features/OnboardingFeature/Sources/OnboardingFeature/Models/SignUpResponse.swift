import Foundation

public struct RegisterStartResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let success: Bool
        public let message: String
        public let resendCodeTimeInSeconds: Int
    }
}

// MARK: - Register Complete Response
public struct RegisterCompleteResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let userId: String
        public let deviceId: String
        public let authCode: String
        public let authTokenResponse: AuthTokenResponse
        public let firebaseToken: String
    }
    
    public struct AuthTokenResponse: Codable {
        public let accessToken: String
        public let refreshToken: String
    }
}

// MARK: - Resend Registration Code Models

public struct ResendRegistrationCodeRequest: Codable {
    public let email: String
    
    public init(email: String) {
        self.email = email
    }
}

public struct ResendRegistrationCodeResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let success: Bool
        public let message: String
        public let resendCodeTimeInSeconds: Int
    }
}

// MARK: - Sign Out Response
public struct SignOutResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let success: Bool
        public let message: String
    }
}

// MARK: - Sign In Request
public struct SignInRequest: Codable {
    public let email: String
    public let password: String
    public let deviceId: String?
    
    public init(email: String, password: String, deviceId: String? = nil) {
        self.email = email
        self.password = password
        self.deviceId = deviceId
    }
}

// MARK: - Sign In Response
public struct SignInResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let userId: String
        public let deviceId: String
        public let authCode: String
        public let authTokenResponse: AuthTokenResponse?  // Optional - not present when MFA required
        public let firebaseToken: String?  // Optional - not present when MFA required
    }
    
    public struct AuthTokenResponse: Codable {
        public let accessToken: String
        public let refreshToken: String
    }
    
    /// Check if MFA is required
    public var requiresMFA: Bool {
        data.authCode == "SUCCESS_NEED_MFA"
    }
}

// MARK: - MFA Send Request
public struct MFASendRequest: Codable {
    public let userId: String
    public let deviceId: String
    
    public init(userId: String, deviceId: String) {
        self.userId = userId
        self.deviceId = deviceId
    }
}

// MARK: - MFA Send Response
public struct MFASendResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let newCodeSent: Bool
        public let expiresInSeconds: Int
        public let resendCodeTimeInSeconds: Int
    }
}

// MARK: - MFA Verify Request
public struct MFAVerifyRequest: Codable {
    public let userId: String
    public let deviceId: String
    public let code: String
    
    public init(userId: String, deviceId: String, code: String) {
        self.userId = userId
        self.deviceId = deviceId
        self.code = code
    }
}

// MARK: - MFA Verify Response (same structure as SignIn success)
public struct MFAVerifyResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let userId: String
        public let deviceId: String
        public let authCode: String
        public let authTokenResponse: AuthTokenResponse
        public let firebaseToken: String
    }
    
    public struct AuthTokenResponse: Codable {
        public let accessToken: String
        public let refreshToken: String
    }
}

// MARK: - Forgot Password Models

public struct ForgotPasswordRequest: Codable {
    public let email: String
    
    public init(email: String) {
        self.email = email
    }
}

public struct ForgotPasswordResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let userId: String
        public let newCodeSent: Bool
        public let expiresInSeconds: Int
        public let resendCodeTimeInSeconds: Int
    }
}

// MARK: - Verify Reset MFA Models

public struct VerifyResetMFARequest: Codable {
    public let userId: String
    public let code: String
    
    public init(userId: String, code: String) {
        self.userId = userId
        self.code = code
    }
}

public struct VerifyResetMFAResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let resetToken: String
    }
    
    public init(data: ResponseData) {
        self.data = data
    }
}

// MARK: - Reset Password Models

public struct ResetPasswordRequest: Codable {
    public let newPassword: String
    
    public init(newPassword: String) {
        self.newPassword = newPassword
    }
}

public struct ResetPasswordResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let success: Bool
        public let message: String
    }
    
    public init(data: ResponseData) {
        self.data = data
    }
}

// MARK: - Refresh Token Models

public struct RefreshTokenRequest: Codable {
    public let userId: String
    public let deviceId: String
    public let refreshToken: String

    public init(userId: String, deviceId: String, refreshToken: String) {
        self.userId = userId
        self.deviceId = deviceId
        self.refreshToken = refreshToken
    }
}

public struct RefreshTokenResponse: Codable {
    public let data: ResponseData
    
    public struct ResponseData: Codable {
        public let authTokenResponse: AuthTokenResponse
        public let authCode: String
    }
    
    public struct AuthTokenResponse: Codable {
        public let accessToken: String
        public let refreshToken: String?  // Optional - only present if rotated
    }
}
