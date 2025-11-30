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
    private let cleanupScheduler = DataCleanupScheduler.shared
    
    init() {
        // 启动数据清理定时任务
        cleanupScheduler.startScheduledCleanup()
        
        // ✅ 启动缓存预热（后台执行，不阻塞启动）
        CachePreloader.shared.startPreloading()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
        }
    }
}
