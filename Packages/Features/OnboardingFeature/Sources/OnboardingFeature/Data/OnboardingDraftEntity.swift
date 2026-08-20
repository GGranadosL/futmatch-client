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
    /// Google identity this draft belongs to. `nil` for a password sign-up.
    /// `(googleIssuer, googleSubject)` is the durable key the backend uses,
    /// and is what a resumed Google onboarding is matched against.
    @NSManaged var googleIssuer: String?
    @NSManaged var googleSubject: String?
    @NSManaged var googlePictureURL: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date

    static func fetchRequest() -> NSFetchRequest<OnboardingDraftEntity> {
        NSFetchRequest<OnboardingDraftEntity>(entityName: "OnboardingDraftEntity")
    }

    static func deleteFetchRequest() -> NSFetchRequest<NSFetchRequestResult> {
        NSFetchRequest<NSFetchRequestResult>(entityName: "OnboardingDraftEntity")
    }
}
