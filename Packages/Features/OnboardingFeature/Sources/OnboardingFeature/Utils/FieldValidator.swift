import Foundation

// MARK: - Field Validator

/// Centralizes all validation logic based on backend rules
public struct FieldValidator {
    
    // MARK: - Name/LastName Validation
    
    /// Validates name or lastName field
    /// - Rules:
    ///   - Not empty
    ///   - Max 30 characters
    ///   - Only letters, accents, and spaces (no numbers)
    ///   - Regex: ^[\p{L}\s]*$
    public static func validateName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            return .invalid(L10n.Validation.fieldRequired)
        }
        
        guard trimmed.count <= 30 else {
            return .invalid(L10n.Validation.maxCharacters(30))
        }
        
        // Unicode pattern that allows letters (including accents) and spaces
        let nameRegex = "^[\\p{L}\\s]*$"
        guard NSPredicate(format: "SELF MATCHES %@", nameRegex).evaluate(with: trimmed) else {
            return .invalid(L10n.Validation.onlyLetters)
        }
        
        return .valid
    }
    
    // MARK: - Email Validation
    
    /// Validates email field
    /// - Rules:
    ///   - Must match standard email format
    ///   - Regex: ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$
    public static func validateEmail(_ email: String) -> ValidationResult {
        let emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        
        guard NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email) else {
            return .invalid(L10n.Validation.invalidEmail)
        }
        
        return .valid
    }
    
    // MARK: - Phone Validation
    
    /// Validates phone field
    /// - Rules:
    ///   - Must be a valid phone number
    ///   - Regex: ^\+?[1-9]\d{1,14}$
    public static func validatePhone(_ phone: String) -> ValidationResult {
        let phoneRegex = "^\\+?[1-9]\\d{1,14}$"
        
        guard NSPredicate(format: "SELF MATCHES %@", phoneRegex).evaluate(with: phone) else {
            return .invalid(L10n.Validation.invalidPhone)
        }
        
        return .valid
    }
    
    // MARK: - Password Validation
    
    /// Validates password field
    /// - Rules:
    ///   - Minimum 8 characters
    ///   - At least 1 uppercase letter
    ///   - At least 1 lowercase letter
    ///   - At least 1 digit
    ///   - At least 1 special character (@$!%*?&.#-_=+)
    ///   - Regex: ^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&.#\-_=+]).{8,}$
    public static func validatePassword(_ password: String) -> ValidationResult {
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&.#\\-_=+]).{8,}$"
        
        guard NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password) else {
            let errors = getPasswordErrors(password)
            return .invalidWithDetails(errors)
        }
        
        return .valid
    }
    
    /// Returns detailed password validation errors
    public static func getPasswordErrors(_ password: String) -> [String] {
        var errors: [String] = []
        
        if password.count < 8 {
            errors.append(L10n.Validation.minPasswordLength)
        }
        if password.range(of: "[A-Z]", options: .regularExpression) == nil {
            errors.append(L10n.Validation.requiresUppercase)
        }
        if password.range(of: "[a-z]", options: .regularExpression) == nil {
            errors.append(L10n.Validation.requiresLowercase)
        }
        if password.range(of: "[0-9]", options: .regularExpression) == nil {
            errors.append(L10n.Validation.requiresNumber)
        }
        if password.range(of: "[@$!%*?&.#\\-_=+]", options: .regularExpression) == nil {
            errors.append(L10n.Validation.requiresSpecialChar)
        }
        
        return errors
    }
    
    // MARK: - Birth Date Validation
    
    /// Validates birth date (must be 18+ years old)
    /// - Parameter birthDate: Timestamp in milliseconds
    public static func validateBirthDate(_ birthDate: Int64) -> ValidationResult {
        let birthDateInSeconds = TimeInterval(birthDate / 1000)
        let date = Date(timeIntervalSince1970: birthDateInSeconds)
        
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: date, to: Date())
        
        guard let age = ageComponents.year, age >= 18 else {
            return .invalid(L10n.Validation.minimumAge(18))
        }
        
        return .valid
    }
    
    /// Validates birth date from Date object
    public static func validateBirthDate(_ birthDate: Date) -> ValidationResult {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        
        guard let age = ageComponents.year, age >= 18 else {
            return .invalid(L10n.Validation.minimumAge(18))
        }
        
        return .valid
    }
    
    // MARK: - UUID Validation
    
    /// Validates that UUID is not empty
    /// - Returns: true if valid, false if empty UUID
    public static func validateUUID(_ uuid: String) -> ValidationResult {
        let emptyUUID = "00000000-0000-0000-0000-000000000000"
        
        guard !uuid.isEmpty, uuid != emptyUUID else {
            return .invalid(L10n.Validation.invalidUUID)
        }
        
        return .valid
    }
    
    // MARK: - Code Validation
    
    /// Validates verification/MFA code
    /// - Returns: true if not empty or blank
    public static func validateCode(_ code: String) -> ValidationResult {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            return .invalid(L10n.Validation.codeRequired)
        }
        
        return .valid
    }
}

// MARK: - Validation Result

public enum ValidationResult {
    case valid
    case invalid(String)
    case invalidWithDetails([String])
    
    public var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    public var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message):
            return message
        case .invalidWithDetails(let errors):
            return errors.joined(separator: "\n")
        }
    }
    
    public var errors: [String] {
        switch self {
        case .valid:
            return []
        case .invalid(let message):
            return [message]
        case .invalidWithDetails(let errors):
            return errors
        }
    }
}
