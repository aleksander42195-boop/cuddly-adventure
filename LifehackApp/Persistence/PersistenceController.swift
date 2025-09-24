import Foundation
import CoreData
#if canImport(SwiftData)
import SwiftData
#endif

final class PersistenceController {
    static let shared = PersistenceController()

    // Core Data stack (placeholder)
    lazy var container: NSPersistentContainer = {
        let c = NSPersistentContainer(name: "LifehackModel")
        c.loadPersistentStores { _, _ in }
        return c
    }()

    var contextIfAvailable: NSManagedObjectContext {
        container.viewContext
    }

    private init() {}
}
