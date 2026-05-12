import Foundation
import CoreData

/// Persistence Manager for Onboarding Feature
/// Uses the shared NSPersistentContainer from the main app
public final class OnboardingPersistenceManager {
    private let container: NSPersistentContainer
    
    public init(container: NSPersistentContainer) {
        self.container = container
    }
    
    /// Get the main view context
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Create a new background context
    public func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
    
    /// Save context if there are changes
    public func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("❌ Failed to save context: \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
