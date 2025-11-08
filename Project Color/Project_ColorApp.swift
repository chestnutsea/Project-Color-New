//
//  Project_ColorApp.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/8.
//

import SwiftUI
import CoreData

@main
struct Project_ColorApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
