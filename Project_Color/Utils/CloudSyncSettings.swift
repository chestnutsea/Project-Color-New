//
//  CloudSyncSettings.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/24.
//  管理 iCloud 同步相关用户偏好设置
//

import Foundation

/// iCloud 同步设置管理器
final class CloudSyncSettings {
    static let shared = CloudSyncSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private let syncEnabledKey = "iCloudSyncEnabled"
    
    private init() {}
    
    // MARK: - Properties
    
    /// 是否启用 iCloud 同步
    var isSyncEnabled: Bool {
        get { defaults.bool(forKey: syncEnabledKey) }
        set { 
            defaults.set(newValue, forKey: syncEnabledKey)
            defaults.synchronize()
        }
    }
    
    // MARK: - Methods
    
    /// 重置所有设置（用于测试）
    func reset() {
        defaults.removeObject(forKey: syncEnabledKey)
        defaults.synchronize()
    }
}

