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
    public let countryISO: String
    public let currentStep: Int
    /// Google identity that owns this draft, or `nil` for a password sign-up.
    /// The ID token is deliberately absent — the backend forbids persisting it,
    /// so a resumed onboarding mints a fresh one instead.
    public let googleIssuer: String?
    public let googleSubject: String?
    public let googlePictureURL: String?
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
        countryISO: String = "",
        currentStep: Int = 1,
        googleIssuer: String? = nil,
        googleSubject: String? = nil,
        googlePictureURL: String? = nil,
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
        self.countryISO = countryISO
        self.currentStep = currentStep
        self.googleIssuer = googleIssuer
        self.googleSubject = googleSubject
        self.googlePictureURL = googlePictureURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Whether this draft belongs to the given Google identity.
    /// A draft from a password sign-up, or from a different Google account,
    /// must never be restored into the current flow.
    public func belongsTo(issuer: String, subject: String) -> Bool {
        googleIssuer == issuer && googleSubject == subject
    }

    /// `true` when this draft came from a Google sign-up.
    public var isGoogleDraft: Bool {
        googleSubject?.isEmpty == false
    }

    /// Check if draft has expired (older than 24 hours)
    public var isExpired: Bool {
        createdAt.timeIntervalSinceNow < -86400
    }
}
