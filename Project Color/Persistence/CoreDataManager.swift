//
//  CoreDataManager.swift
//  Project Color
//
//  Created by ChatGPT on 2025/11/8.
//

import CoreData
import Foundation

final class CoreDataManager {

    static let shared = CoreDataManager()

    static let preview: CoreDataManager = {
        let manager = CoreDataManager(inMemory: true, shouldSeedPreview: true)
        return manager
    }()

    let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    private init(inMemory: Bool = false, shouldSeedPreview: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Project_Color")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        configure(context: container.viewContext, name: "viewContext")
        container.viewContext.automaticallyMergesChangesFromParent = true

        if shouldSeedPreview {
            seedPreviewData()
        }
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        configure(context: context, name: "backgroundContext")
        return context
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            self.configure(context: context, name: "performBackgroundTaskContext")
            block(context)
        }
    }

    @discardableResult
    func save(context: NSManagedObjectContext? = nil) throws -> Bool {
        let contextToSave = context ?? viewContext
        guard contextToSave.hasChanges else { return false }
        try contextToSave.save()
        return true
    }

    private func configure(context: NSManagedObjectContext, name: String) {
        context.name = name
        context.transactionAuthor = "ProjectColor"
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
    }

    private func seedPreviewData() {
        let context = viewContext

        (0..<3).forEach { index in
            let photo = PhotoEntity(context: context)
            photo.id = UUID()
            photo.assetLocalId = "preview-\(index)"
            photo.timestamp = Date().addingTimeInterval(Double(-index) * 3600)
            photo.toneCategory = index % 2 == 0 ? "warm" : "cool"
            photo.sceneLabel = index % 2 == 0 ? "outdoor" : "indoor"
            photo.styleLabel = index % 2 == 0 ? "复古" : "奶油"

            let style = StyleEntity(context: context)
            style.id = UUID()
            style.label = index % 2 == 0 ? "Vintage" : "Creamy"
            style.sourceModel = "Demo"
            style.confidence = 0.8
            style.addToPhotos(photo)

            let swatch = ColorSwatchEntity(context: context)
            swatch.id = UUID()
            swatch.hex = index % 2 == 0 ? "#F2D7D5" : "#D4E6F1"
            swatch.l = 60 + Double(index) * 5
            swatch.a = 5 + Double(index)
            swatch.b = 10 + Double(index) * 2
            swatch.ratio = 0.35 + Double(index) * 0.1
            swatch.photo = photo

            let feature = FeatureEntity(context: context)
            feature.id = UUID()
            feature.modelSource = "CLIP"
            feature.dimension = 3
            feature.vector = PhotoFeature.encode(vector: [0.1 * Float(index + 1),
                                                          0.2 * Float(index + 1),
                                                          0.3 * Float(index + 1)])
            feature.photo = photo
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Failed seeding preview data: \(error)")
        }
    }
}

