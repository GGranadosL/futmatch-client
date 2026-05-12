import Foundation

/// Domain model for Onboarding draft data
public struct OnboardingDraft: Codable {
    public let firstName: String
    public let lastName: String
    public let birthDate: Date?
    public let gender: String?
    public let email: String
    public let phoneCountryCode: String
    public let phone: String
    public let country: String
    public let currentStep: Int
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        firstName: String = "",
        lastName: String = "",
        birthDate: Date? = nil,
        gender: String? = nil,
        email: String = "",
        phoneCountryCode: String = "+52",
        phone: String = "",
        country: String = "",
        currentStep: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
        self.gender = gender
        self.email = email
        self.phoneCountryCode = phoneCountryCode
        self.phone = phone
        self.country = country
        self.currentStep = currentStep
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Check if draft has expired (older than 24 hours)
    public var isExpired: Bool {
        createdAt.timeIntervalSinceNow < -86400
    }
}
