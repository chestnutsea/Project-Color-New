//
//  DataController.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/9.
//

import CoreData
import Foundation
import Combine

/// 中央数据控制器：负责 Core Data 的加载与全局共享
final class DataController: ObservableObject {
    static let shared = DataController()

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Project_Color")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                fatalError("❌ Failed to load Core Data store: \(error.localizedDescription)")
            } else {
                print("✅ Core Data store loaded: \(storeDescription.url?.path ?? "")")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var context: NSManagedObjectContext {
        container.viewContext
    }

    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Error saving Core Data context: \(error.localizedDescription)")
            }
        }
    }
}
