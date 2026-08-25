import CoreData

@objc(OnboardingDraftEntity)
final class OnboardingDraftEntity: NSManagedObject {
    @NSManaged var firstName: String
    @NSManaged var lastName: String
    @NSManaged var birthDate: Date?
    @NSManaged var gender: String?
    @NSManaged var email: String
    @NSManaged var phoneCountryCode: String
    @NSManaged var phone: String
    @NSManaged var country: String
    @NSManaged var countryISO: String?
    @NSManaged var currentStep: Int16
    /// Social identity this draft belongs to. `nil` for a password sign-up.
    /// `(socialProvider, socialIssuer, socialSubject)` is the durable key the
    /// backend uses, and is what a resumed social onboarding is matched against.
    @NSManaged var socialProvider: String?
    @NSManaged var socialIssuer: String?
    @NSManaged var socialSubject: String?
    @NSManaged var socialPictureURL: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date

    static func fetchRequest() -> NSFetchRequest<OnboardingDraftEntity> {
        NSFetchRequest<OnboardingDraftEntity>(entityName: "OnboardingDraftEntity")
    }

    static func deleteFetchRequest() -> NSFetchRequest<NSFetchRequestResult> {
        NSFetchRequest<NSFetchRequestResult>(entityName: "OnboardingDraftEntity")
    }
}
