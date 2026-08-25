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
    /// Social provider that owns this draft, or `nil` for a password sign-up.
    /// The credential itself is deliberately absent — both backends forbid
    /// persisting it, so a resumed onboarding always obtains a fresh one instead.
    public let provider: AuthProvider?
    public let socialIssuer: String?
    public let socialSubject: String?
    public let socialPictureURL: String?
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
        provider: AuthProvider? = nil,
        socialIssuer: String? = nil,
        socialSubject: String? = nil,
        socialPictureURL: String? = nil,
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
        self.provider = provider
        self.socialIssuer = socialIssuer
        self.socialSubject = socialSubject
        self.socialPictureURL = socialPictureURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// The durable identity this draft belongs to, or `nil` for a password
    /// sign-up. Non-nil identities compare on provider, issuer, AND subject — a
    /// Google draft and an Apple identity differ just as much as two different
    /// Google accounts do.
    public var socialIdentity: SocialDraftIdentity? {
        guard let provider, let socialIssuer, let socialSubject, !socialSubject.isEmpty else { return nil }
        return SocialDraftIdentity(provider: provider, issuer: socialIssuer, subject: socialSubject)
    }

    /// `true` when this draft came from a social sign-up (any provider).
    public var isSocialDraft: Bool {
        socialIdentity != nil
    }

    /// Check if draft has expired (older than 24 hours)
    public var isExpired: Bool {
        createdAt.timeIntervalSinceNow < -86400
    }
}
