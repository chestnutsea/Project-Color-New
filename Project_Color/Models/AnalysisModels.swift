//
//  AnalysisModels.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 1: 内存临时数据结构
//

import Foundation
import SwiftUI
import Combine

// MARK: - 单张照片的颜色信息
struct PhotoColorInfo: Identifiable {
    let id = UUID()
    let assetIdentifier: String
    var dominantColors: [DominantColor] = []  // 5个主色
    var primaryClusterIndex: Int?  // 所属主簇
    var clusterMix: [Int: Double] = [:]  // 各簇占比
}

// MARK: - 主色结构
struct DominantColor: Identifiable, Codable {
    let id = UUID()
    var rgb: SIMD3<Float>  // 0-1范围
    var hex: String
    var weight: Float  // 占比 0-1
    var colorName: String = ""
    
    // 便捷初始化
    init(rgb: SIMD3<Float>, weight: Float) {
        self.rgb = rgb
        self.weight = weight
        self.hex = DominantColor.rgbToHex(rgb)
    }
    
    // RGB转Hex
    static func rgbToHex(_ rgb: SIMD3<Float>) -> String {
        let r = Int(rgb.x * 255)
        let g = Int(rgb.y * 255)
        let b = Int(rgb.z * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    // 转为SwiftUI Color
    var color: Color {
        Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
    }
}

// MARK: - 颜色簇
struct ColorCluster: Identifiable {
    let id = UUID()
    var index: Int
    var centroid: SIMD3<Float>  // RGB质心
    var colorName: String
    var photoCount: Int = 0
    var photoIdentifiers: [String] = []
    
    var hex: String {
        DominantColor.rgbToHex(centroid)
    }
    
    var color: Color {
        Color(red: Double(centroid.x), green: Double(centroid.y), blue: Double(centroid.z))
    }
}

// MARK: - 分析结果（ObservableObject）
class AnalysisResult: ObservableObject {
    @Published var clusters: [ColorCluster] = []
    @Published var photoInfos: [PhotoColorInfo] = []
    @Published var totalPhotoCount: Int = 0
    @Published var processedCount: Int = 0
    @Published var failedCount: Int = 0
    @Published var isCompleted: Bool = false
    @Published var timestamp: Date = Date()
    
    // Phase 4: 聚类质量指标
    @Published var silhouetteScore: Double = 0.0
    @Published var optimalK: Int = 5
    @Published var qualityLevel: String = "未知"
    @Published var qualityDescription: String = ""
    @Published var allKScores: [Int: Double] = [:]  // 各K值的得分
    
    // 根据簇索引获取照片
    func photos(in clusterIndex: Int) -> [PhotoColorInfo] {
        return photoInfos.filter { $0.primaryClusterIndex == clusterIndex }
    }
}

// MARK: - 分析进度
struct AnalysisProgress {
    var currentPhoto: Int = 0
    var totalPhotos: Int = 0
    var currentStage: String = ""
    var overallProgress: Double = 0.0
    var failedCount: Int = 0
    
    // Phase 4: K值选择进度
    var currentK: Int = 0
    var totalK: Int = 0
    var isSelectingK: Bool = false
    
    // Phase 4+: 预计剩余时间
    var estimatedTimeRemaining: TimeInterval = 0
    var startTime: Date = Date()
    
    // Phase 5: 缓存与并发信息
    var cachedCount: Int = 0
    var isConcurrent: Bool = false
    var adaptiveOperations: [String] = []
    
    var progressText: String {
        if isSelectingK && totalK > 0 {
            let concurrent = isConcurrent ? "（并发）" : ""
            return "\(currentStage)\(concurrent)\n正在测试 K=\(currentK) (\(currentK)/\(totalK))"
        } else if !currentStage.isEmpty {
            let concurrent = isConcurrent ? "（并发）" : ""
            let cacheInfo = cachedCount > 0 ? "（缓存: \(cachedCount)）" : ""
            return "\(currentStage)\(concurrent)\(cacheInfo)\n正在处理 \(currentPhoto)/\(totalPhotos) 张照片"
        } else {
            return "正在处理 \(currentPhoto)/\(totalPhotos) 张照片"
        }
    }
    
    var percentageText: String {
        return String(format: "%.0f%%", overallProgress * 100)
    }
    
    var timeRemainingText: String {
        if estimatedTimeRemaining <= 0 {
            return ""
        }
        
        let minutes = Int(estimatedTimeRemaining) / 60
        let seconds = Int(estimatedTimeRemaining) % 60
        
        if minutes > 0 {
            return "预计剩余 \(minutes)分\(seconds)秒"
        } else {
            return "预计剩余 \(seconds)秒"
        }
    }
    
    var detailText: String {
        var details: [String] = []
        
        if cachedCount > 0 {
            details.append("✅ 缓存命中: \(cachedCount) 张")
        }
        
        if isConcurrent {
            details.append("⚡️ 并发处理中")
        }
        
        if !adaptiveOperations.isEmpty {
            details.append("🔄 自适应更新: \(adaptiveOperations.count) 项")
        }
        
        if failedCount > 0 {
            details.append("⚠️ 失败: \(failedCount) 张")
        }
        
        return details.joined(separator: " • ")
    }
}

