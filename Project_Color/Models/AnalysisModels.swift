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
    var warmCoolScore: WarmCoolScore? = nil  // 冷暖评分
    var imageFeature: ImageFeature? = nil  // 图像特征（风格分析）
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
    
    // AI 颜色评价
    @Published var aiEvaluation: ColorEvaluation? = nil
    
    // 冷暖色调分布
    @Published var warmCoolDistribution: WarmCoolDistribution? = nil
    
    // 色彩统计数据（按需计算）
    @Published var globalStatistics: GlobalColorStatistics? = nil
    @Published var clusterAnalytics: [ClusterAnalytics]? = nil
    
    // 风格分析数据
    @Published var collectionFeature: CollectionFeature? = nil
    
    // 根据簇索引获取照片
    func photos(in clusterIndex: Int) -> [PhotoColorInfo] {
        return photoInfos.filter { $0.primaryClusterIndex == clusterIndex }
    }
}

// MARK: - AI 颜色评价
struct ColorEvaluation {
    var isLoading: Bool = false
    var error: String? = nil
    var completedAt: Date? = nil
    
    // 整体评价
    var overallEvaluation: OverallEvaluation? = nil
    
    // 各簇评价
    var clusterEvaluations: [ClusterEvaluation] = []
}

// MARK: - 整体评价
struct OverallEvaluation {
    var hueAnalysis: String  // 色调分析
    var saturationAnalysis: String  // 饱和度分析
    var brightnessAnalysis: String  // 明度分析
    var fullText: String  // 完整评价文本
}

// MARK: - 单簇评价
struct ClusterEvaluation: Identifiable {
    var id: Int { clusterIndex }
    var clusterIndex: Int
    var colorName: String
    var hexValue: String
    var evaluation: String
}

// MARK: - 色彩统计数据模型

/// 聚类统计信息
struct ClusterStatistics {
    /// 色相范围（度数，0-360）
    let hueRange: (min: Float, max: Float)
    /// 色相标准差
    let hueStdDev: Float
    
    /// 明度范围（0-1）
    let lightnessRange: (min: Float, max: Float)
    /// 明度标准差
    let lightnessStdDev: Float
    
    /// 饱和度范围（0-1）
    let saturationRange: (min: Float, max: Float)
    /// 饱和度标准差
    let saturationStdDev: Float
    
    /// 聚类内部一致性评分（0-1，越高越一致）
    let consistency: Float
    
    /// 照片数量
    let photoCount: Int
}

/// 全局色彩统计信息
struct GlobalColorStatistics {
    /// 整体色调倾向（基于色相分布）
    let dominantHueRange: String  // 如 "橙-黄色系"、"蓝-青色系"
    
    /// 整体影调倾向
    let dominantValue: String  // "高调"、"中调"、"低调"
    let averageLightness: Float
    
    /// 整体饱和度倾向
    let dominantSaturation: String  // "艳丽"、"柔和"、"灰调"
    let averageSaturation: Float
    
    /// 色相分布统计（主要色相区间及其占比）
    let hueDistribution: [(range: String, percentage: Float)]
    
    /// 明度分布统计
    let lightnessDistribution: [(range: String, percentage: Float)]
    
    /// 饱和度分布统计
    let saturationDistribution: [(range: String, percentage: Float)]
}

/// 聚类分析数据（包含聚类及其统计信息）
struct ClusterAnalytics {
    let cluster: ColorCluster
    let statistics: ClusterStatistics
}

// MARK: - 冷暖色调评分
struct WarmCoolScore {
    // 核心分数
    var overallScore: Float        // 最终融合得分 [-1, 1]（70% 局部 + 30% 代表色）
    
    // 分解分数（用于调试和分析）
    var labBScore: Float           // 局部结构得分（SLIC-based）[-1, 1]
    var dominantWarmth: Float      // 代表色得分（全局调性）[-1, 1]
    
    // 兼容性字段（保留但不再使用）
    var hueWarmth: Float           // 已废弃
    var warmPixelRatio: Float      // 已废弃
    var coolPixelRatio: Float      // 已废弃
    var neutralPixelRatio: Float   // 已废弃
    
    // 辅助数据
    var labBMean: Float            // Lab b通道均值（等同于 labBScore）
    var overallWarmth: Float       // 调试用：代表色暖度
    var overallCoolness: Float     // 调试用：代表色冷度
    
    // 风格分析数据（用于后续计算 ImageFeature）
    var slicData: SLICAnalysisData?   // SLIC 分割数据
    var hslData: HSLAnalysisData?     // HSL 统计数据
}

// MARK: - 风格分析辅助数据

/// SLIC 分析数据（用于风格分析）
struct SLICAnalysisData {
    let labBuffer: [Float]
    let labels: [Int]
    let width: Int
    let height: Int
}

/// HSL 分析数据（用于风格分析）
struct HSLAnalysisData {
    let hslList: [(h: Float, s: Float, l: Float)]
}

// MARK: - 所有照片的冷暖分布数据
struct WarmCoolDistribution {
    var scores: [String: WarmCoolScore]  // assetIdentifier -> score
    var histogram: [Float]                // 直方图数据（分档统计）
    var histogramBins: Int = 20           // 直方图分档数
    var minScore: Float = -1.0
    var maxScore: Float = 1.0
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

