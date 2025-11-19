//
//  DataCleanupScheduler.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/19.
//  数据清理定时任务调度器
//

import Foundation

/// 数据清理定时任务调度器
class DataCleanupScheduler {
    static let shared = DataCleanupScheduler()
    
    private let coreDataManager = CoreDataManager.shared
    private var cleanupTimer: Timer?
    
    // 清理间隔（默认每天检查一次）
    private let cleanupInterval: TimeInterval = 24 * 60 * 60  // 24小时
    
    // 数据保留天数
    private let retentionDays: Int = 7
    
    private init() {}
    
    // MARK: - 启动定时任务
    
    /// 启动定时清理任务
    func startScheduledCleanup() {
        print("📅 启动数据清理定时任务")
        print("   - 清理间隔: 每 24 小时")
        print("   - 保留天数: \(retentionDays) 天")
        
        // 立即执行一次清理
        performCleanup()
        
        // 设置定时器（每24小时执行一次）
        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: cleanupInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performCleanup()
        }
        
        // 确保定时器在后台也能运行
        if let timer = cleanupTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    /// 停止定时任务
    func stopScheduledCleanup() {
        print("⏹️ 停止数据清理定时任务")
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    // MARK: - 执行清理
    
    /// 执行数据清理
    private func performCleanup() {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧹 开始执行数据清理任务")
        print("   时间: \(Date())")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 获取清理前的统计信息
        let beforeStats = coreDataManager.getDataStatistics()
        print("📊 清理前统计:")
        print("   - 总会话数: \(beforeStats.total)")
        print("   - 我的作品: \(beforeStats.personalWork)")
        print("   - 其他图像: \(beforeStats.otherImage)")
        print("   - 7天内: \(beforeStats.within7Days)")
        
        // 执行清理
        let deletedCount = coreDataManager.cleanupOldOtherImageSessions(olderThanDays: retentionDays)
        
        // 获取清理后的统计信息
        let afterStats = coreDataManager.getDataStatistics()
        print("\n📊 清理后统计:")
        print("   - 总会话数: \(afterStats.total)")
        print("   - 我的作品: \(afterStats.personalWork)")
        print("   - 其他图像: \(afterStats.otherImage)")
        print("   - 7天内: \(afterStats.within7Days)")
        print("\n✅ 清理任务完成，删除了 \(deletedCount) 个旧会话")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    /// 手动触发清理（用于测试或用户手动操作）
    func manualCleanup() {
        print("🔧 手动触发数据清理")
        performCleanup()
    }
}

