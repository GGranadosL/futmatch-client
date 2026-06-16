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
    @NSManaged var currentStep: Int16
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date

    static func fetchRequest() -> NSFetchRequest<OnboardingDraftEntity> {
        NSFetchRequest<OnboardingDraftEntity>(entityName: "OnboardingDraftEntity")
    }

    static func deleteFetchRequest() -> NSFetchRequest<NSFetchRequestResult> {
        NSFetchRequest<NSFetchRequestResult>(entityName: "OnboardingDraftEntity")
    }
}
