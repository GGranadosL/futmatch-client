import Foundation

// MARK: - Request Validators

/// Extension to validate RegisterStartRequest before sending to API
extension RegisterStartRequest {
    
    /// Validates all fields according to backend rules
    /// - Throws: RequestValidationError if any field is invalid
    public func validate() throws {
        // Validate name
        let nameResult = FieldValidator.validateName(name)
        guard nameResult.isValid else {
            throw RequestValidationError.invalidField("name", nameResult.errorMessage ?? "Invalid name")
        }
        
        // Validate lastName
        let lastNameResult = FieldValidator.validateName(lastName)
        guard lastNameResult.isValid else {
            throw RequestValidationError.invalidField("lastName", lastNameResult.errorMessage ?? "Invalid lastName")
        }
        
        // Validate email
        let emailResult = FieldValidator.validateEmail(email)
        guard emailResult.isValid else {
            throw RequestValidationError.invalidField("email", emailResult.errorMessage ?? "Invalid email")
        }
        
        // Validate phone
        let phoneResult = FieldValidator.validatePhone(phone)
        guard phoneResult.isValid else {
            throw RequestValidationError.invalidField("phone", phoneResult.errorMessage ?? "Invalid phone")
        }
        
        // Validate password
        let passwordResult = FieldValidator.validatePassword(password)
        guard passwordResult.isValid else {
            throw RequestValidationError.invalidField("password", passwordResult.errorMessage ?? "Invalid password")
        }
        
        // Validate birthDate (18+ years)
        let birthDateResult = FieldValidator.validateBirthDate(birthDate)
        guard birthDateResult.isValid else {
            throw RequestValidationError.invalidField("birthDate", birthDateResult.errorMessage ?? "Invalid birthDate")
        }
        
        // Validate country is not empty
        guard !country.isEmpty else {
            throw RequestValidationError.missingRequiredField("country")
        }
    }
}

/// Extension to validate SignInRequest before sending to API
extension SignInRequest {
    
    /// Validates all fields according to backend rules
    /// - Throws: RequestValidationError if any field is invalid
    public func validate() throws {
        // Validate email
        let emailResult = FieldValidator.validateEmail(email)
        guard emailResult.isValid else {
            throw RequestValidationError.invalidField("email", emailResult.errorMessage ?? "Invalid email")
        }
        
        // Validate password
        let passwordResult = FieldValidator.validatePassword(password)
        guard passwordResult.isValid else {
            throw RequestValidationError.invalidField("password", passwordResult.errorMessage ?? "Invalid password")
        }
        
        // Validate deviceId if present
        if let deviceId = deviceId {
            let deviceIdResult = FieldValidator.validateUUID(deviceId)
            guard deviceIdResult.isValid else {
                throw RequestValidationError.invalidField("deviceId", deviceIdResult.errorMessage ?? "Invalid deviceId")
            }
        }
    }
}

/// Extension to validate MFASendRequest before sending to API
extension MFASendRequest {
    
    /// Validates all fields according to backend rules
    /// - Throws: RequestValidationError if any field is invalid
    public func validate() throws {
        // Validate userId
        let userIdResult = FieldValidator.validateUUID(userId)
        guard userIdResult.isValid else {
            throw RequestValidationError.invalidField("userId", userIdResult.errorMessage ?? "Invalid userId")
        }
        
        // Validate deviceId
        let deviceIdResult = FieldValidator.validateUUID(deviceId)
        guard deviceIdResult.isValid else {
            throw RequestValidationError.invalidField("deviceId", deviceIdResult.errorMessage ?? "Invalid deviceId")
        }
    }
}

/// Extension to validate MFAVerifyRequest before sending to API
extension MFAVerifyRequest {
    
    /// Validates all fields according to backend rules
    /// - Throws: RequestValidationError if any field is invalid
    public func validate() throws {
        // Validate userId
        let userIdResult = FieldValidator.validateUUID(userId)
        guard userIdResult.isValid else {
            throw RequestValidationError.invalidField("userId", userIdResult.errorMessage ?? "Invalid userId")
        }
        
        // Validate deviceId
        let deviceIdResult = FieldValidator.validateUUID(deviceId)
        guard deviceIdResult.isValid else {
            throw RequestValidationError.invalidField("deviceId", deviceIdResult.errorMessage ?? "Invalid deviceId")
        }
        
        // Validate code
        let codeResult = FieldValidator.validateCode(code)
        guard codeResult.isValid else {
            throw RequestValidationError.invalidField("code", codeResult.errorMessage ?? "Invalid code")
        }
    }
}

/// Extension to validate RefreshTokenRequest before sending to API
extension RefreshTokenRequest {
    
    /// Validates all fields according to backend rules
    /// - Throws: RequestValidationError if any field is invalid
    public func validate() throws {
        // Validate userId
        let userIdResult = FieldValidator.validateUUID(userId)
        guard userIdResult.isValid else {
            throw RequestValidationError.invalidField("userId", userIdResult.errorMessage ?? "Invalid userId")
        }
        
        // Validate deviceId
        let deviceIdResult = FieldValidator.validateUUID(deviceId)
        guard deviceIdResult.isValid else {
            throw RequestValidationError.invalidField("deviceId", deviceIdResult.errorMessage ?? "Invalid deviceId")
        }
    }
}

/// Extension to validate ForgotPasswordRequest before sending to API
extension ForgotPasswordRequest {
    
    /// Validates all fields according to backend rules
    /// - Throws: RequestValidationError if any field is invalid
    public func validate() throws {
        // Validate email
        let emailResult = FieldValidator.validateEmail(email)
        guard emailResult.isValid else {
            throw RequestValidationError.invalidField("email", emailResult.errorMessage ?? "Invalid email")
        }
    }
}

/// Extension to validate VerifyResetMFARequest before sending to API
extension VerifyResetMFARequest {
    
    /// Validates all fields according to backend rules
    /// - Throws: RequestValidationError if any field is invalid
    public func validate() throws {
        // Validate userId
        let userIdResult = FieldValidator.validateUUID(userId)
        guard userIdResult.isValid else {
            throw RequestValidationError.invalidField("userId", userIdResult.errorMessage ?? "Invalid userId")
        }
        
        // Validate code
        let codeResult = FieldValidator.validateCode(code)
        guard codeResult.isValid else {
            throw RequestValidationError.invalidField("code", codeResult.errorMessage ?? "Invalid code")
        }
    }
}

/// Extension to validate ResetPasswordRequest before sending to API
extension ResetPasswordRequest {
    
    /// Validates all fields according to backend rules
    /// - Throws: RequestValidationError if any field is invalid
    public func validate() throws {
        // Validate newPassword
        let passwordResult = FieldValidator.validatePassword(newPassword)
        guard passwordResult.isValid else {
            throw RequestValidationError.invalidField("newPassword", passwordResult.errorMessage ?? "Invalid password")
        }
    }
}

// MARK: - Request Validation Error

public enum RequestValidationError: LocalizedError {
    case invalidField(String, String)
    case missingRequiredField(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidField(let field, let reason):
            return "\(L10n.Validation.fieldRequired): \(field) - \(reason)"
        case .missingRequiredField(let field):
            return "\(L10n.Validation.fieldRequired): \(field)"
        }
    }
}
