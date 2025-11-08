//
//  Project_ColorApp.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/8.
//

import SwiftUI

@main
struct Project_ColorApp: App {
    private let coreDataManager = CoreDataManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
        }
    }
}
