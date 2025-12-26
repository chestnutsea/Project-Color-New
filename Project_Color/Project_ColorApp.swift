//
//  Project_ColorApp.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/8.
//

import SwiftUI

@main
struct Project_ColorApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    private let coreDataManager = CoreDataManager.shared
    private let cleanupScheduler = DataCleanupScheduler.shared
    
    init() {
        // 启动数据清理定时任务
        cleanupScheduler.startScheduledCleanup()
        
        // ⚠️ 禁用缓存预热，避免触发照片库权限检查
        // 保持完全隐私模式：只通过 PHPicker 访问用户选择的照片
        // CachePreloader.shared.startPreloading()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
        }
    }
}
