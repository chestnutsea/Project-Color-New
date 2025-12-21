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
        case tone = "tone"
        case shadow = "shadow"
        case comprehensive = "comprehensive"
        
        var displayName: String {
            switch self {
            case .tone: return L10n.DevelopmentMode.tone.localized
            case .shadow: return L10n.DevelopmentMode.shadow.localized
            case .comprehensive: return L10n.DevelopmentMode.comprehensive.localized
            }
        }
    }
    
    // MARK: - 显影形状
    enum DevelopmentShape: String, Codable, CaseIterable {
        case circle = "circle"
        case flower = "flower"
        case gardenFlower = "gardenFlower"
        
        var displayName: String {
            switch self {
            case .circle: return L10n.DevelopmentShape.circle.localized
            case .flower: return L10n.DevelopmentShape.flower.localized
            case .gardenFlower: return L10n.DevelopmentShape.gardenFlower.localized
            }
        }
    }
    
    // MARK: - 扫描结果页样式
    enum ScanResultStyle: String, Codable, CaseIterable {
        case perspectiveFirst = "perspective_first"
        case compositionFirst = "composition_first"
        
        var displayName: String {
            switch self {
            case .perspectiveFirst: return L10n.ScanResultStyle.perspectiveFirst.localized
            case .compositionFirst: return L10n.ScanResultStyle.compositionFirst.localized
            }
        }
    }
    
    // MARK: - Settings Keys
    private enum SettingsKey {
        static let usePhotoTimeAsDefault = "usePhotoTimeAsDefault"
        static let developmentMode = "developmentMode"
        static let developmentShape = "developmentShape"
        static let developmentFavoriteOnly = "developmentFavoriteOnly"
        static let scanResultStyle = "scanResultStyle"
    }
    
    /// 是否使用照片时间作为默认日期
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
    
    /// 显影模式
    static var developmentMode: DevelopmentMode {
        get {
            // 如果从未设置过，默认为融合模式
            guard let data = UserDefaults.standard.data(forKey: SettingsKey.developmentMode),
                  let mode = try? JSONDecoder().decode(DevelopmentMode.self, from: data) else {
                return .comprehensive
            }
            return mode
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: SettingsKey.developmentMode)
            }
        }
    }
    
    /// 显影形状
    static var developmentShape: DevelopmentShape {
        get {
            // 如果从未设置过，默认为圆形
            guard let data = UserDefaults.standard.data(forKey: SettingsKey.developmentShape),
                  let shape = try? JSONDecoder().decode(DevelopmentShape.self, from: data) else {
                return .circle
            }
            return shape
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: SettingsKey.developmentShape)
            }
        }
    }
    
    /// 只对收藏照片进行显影
    static var developmentFavoriteOnly: Bool {
        get {
            // 如果从未设置过，默认为 false（关闭）
            return UserDefaults.standard.bool(forKey: SettingsKey.developmentFavoriteOnly)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SettingsKey.developmentFavoriteOnly)
        }
    }
    
    /// 扫描结果页样式
    static var scanResultStyle: ScanResultStyle {
        get {
            // 如果从未设置过，默认为视角在前
            guard let data = UserDefaults.standard.data(forKey: SettingsKey.scanResultStyle),
                  let style = try? JSONDecoder().decode(ScanResultStyle.self, from: data) else {
                return .perspectiveFirst
            }
            return style
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: SettingsKey.scanResultStyle)
            }
        }
    }
}

