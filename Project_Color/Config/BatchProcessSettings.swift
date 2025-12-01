//
//  BatchProcessSettings.swift
//  Project_Color
//
//  批处理设置管理
//

import Foundation

/// 批处理设置管理
struct BatchProcessSettings {
    // MARK: - 显影解析方式
    enum DevelopmentMode: String, Codable, CaseIterable {
        case tone = "色调模式"
        case shadow = "影调模式"
        case comprehensive = "综合模式"
    }
    
    // MARK: - Settings Keys
    private enum SettingsKey {
        static let usePhotoTimeAsDefault = "usePhotoTimeAsDefault"
        static let developmentMode = "developmentMode"
    }
    
    /// 是否使用照片时间作为默认名称与日期
    static var usePhotoTimeAsDefault: Bool {
        get {
            // 如果从未设置过，默认为 true
            if UserDefaults.standard.object(forKey: SettingsKey.usePhotoTimeAsDefault) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: SettingsKey.usePhotoTimeAsDefault)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SettingsKey.usePhotoTimeAsDefault)
        }
    }
    
    /// 显影解析方式
    static var developmentMode: DevelopmentMode {
        get {
            // 如果从未设置过，默认为色调模式
            guard let data = UserDefaults.standard.data(forKey: SettingsKey.developmentMode),
                  let mode = try? JSONDecoder().decode(DevelopmentMode.self, from: data) else {
                return .tone
            }
            return mode
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: SettingsKey.developmentMode)
            }
        }
    }
}

