import Foundation

// MARK: - Field Validator

/// Centralizes all validation logic based on backend rules
public struct FieldValidator {

    /// Minimum age required to register, in years.
    public static let minimumAge = 18

    // MARK: - Cached Patterns
    //
    // `NSPredicate(format: "SELF MATCHES %@", ...)` compiles an ICU regex on every call.
    // These run on every keystroke via the ViewModels' computed `is*Valid` properties, so
    // building them fresh each time was measurable overhead on the same path that also
    // triggers a SwiftUI re-render. Compiling them once as `static let` amortizes that cost.

    /// Letters (incl. accents) and spaces only.
    private static let namePredicate = NSPredicate(format: "SELF MATCHES %@", "^[\\p{L}\\s]*$")
    private static let emailPredicate = NSPredicate(
        format: "SELF MATCHES %@", "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    )
    private static let phonePredicate = NSPredicate(format: "SELF MATCHES %@", "^\\+?[1-9]\\d{1,14}$")
    private static let passwordPredicate = NSPredicate(
        format: "SELF MATCHES %@",
        "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&.#\\-_=+]).{8,}$"
    )
    private static let uppercaseCharacterSet = CharacterSet.uppercaseLetters
    private static let lowercaseCharacterSet = CharacterSet.lowercaseLetters
    private static let digitCharacterSet = CharacterSet.decimalDigits
    private static let specialCharacterSet = CharacterSet(charactersIn: "@$!%*?&.#-_=+")

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
        
        guard namePredicate.evaluate(with: trimmed) else {
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
        guard emailPredicate.evaluate(with: email) else {
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
        guard phonePredicate.evaluate(with: phone) else {
            return .invalid(L10n.Validation.invalidPhone)
        }

        return .valid
    }
    
    // MARK: - Password Validation

    /// Validates password for login (minimum length only)
    /// - Rules:
    ///   - Minimum 8 characters
    public static func validatePasswordForLogin(_ password: String) -> ValidationResult {
        guard password.count >= 8 else {
            return .invalid(L10n.Validation.minPasswordLength)
        }
        return .valid
    }

    /// Validates password field (full strength validation)
    /// - Rules:
    ///   - Minimum 8 characters
    ///   - At least 1 uppercase letter
    ///   - At least 1 lowercase letter
    ///   - At least 1 digit
    ///   - At least 1 special character (@$!%*?&.#-_=+)
    ///   - Regex: ^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&.#\-_=+]).{8,}$
    public static func validatePassword(_ password: String) -> ValidationResult {
        guard passwordPredicate.evaluate(with: password) else {
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
        if !password.unicodeScalars.contains(where: uppercaseCharacterSet.contains) {
            errors.append(L10n.Validation.requiresUppercase)
        }
        if !password.unicodeScalars.contains(where: lowercaseCharacterSet.contains) {
            errors.append(L10n.Validation.requiresLowercase)
        }
        if !password.unicodeScalars.contains(where: digitCharacterSet.contains) {
            errors.append(L10n.Validation.requiresNumber)
        }
        if !password.unicodeScalars.contains(where: specialCharacterSet.contains) {
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
        
        guard let age = ageComponents.year, age >= minimumAge else {
            return .invalid(L10n.Validation.minimumAge(minimumAge))
        }
        
        return .valid
    }
    
    /// Validates birth date from Date object
    public static func validateBirthDate(_ birthDate: Date) -> ValidationResult {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        
        guard let age = ageComponents.year, age >= minimumAge else {
            return .invalid(L10n.Validation.minimumAge(minimumAge))
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
