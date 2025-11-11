//
//  Project_ColorApp.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/8.
//

import SwiftUI

@main
struct Project_ColorApp: App {
    private let coreDataManager = CoreDataManager.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
        }
    }
}
