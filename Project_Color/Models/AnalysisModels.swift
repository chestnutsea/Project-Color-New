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
    var advancedColorAnalysis: AdvancedColorAnalysis? = nil  // 高级色彩分析（冷暖、色偏等）
    var imageFeature: ImageFeature? = nil  // 图像特征（风格分析）
    var visionInfo: PhotoVisionInfo? = nil  // Vision 识别信息
    var metadata: PhotoMetadata? = nil  // 照片元数据（EXIF、地理、相机）
    var albumIdentifier: String? = nil  // 相册唯一标识
    var albumName: String? = nil  // 相册名称
    var brightnessCDF: [Float]? = nil  // 亮度累计分布函数（256个值，0-1）
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
    
    // Core Data 会话 ID（保存后设置）
    @Published var sessionId: UUID? = nil
    
    // Phase 4: 聚类质量指标
    @Published var silhouetteScore: Double = 0.0
    @Published var optimalK: Int = 5
    @Published var qualityLevel: String = "未知"
    @Published var qualityDescription: String = ""
    @Published var allKScores: [Int: Double] = [:]  // 各K值的得分
    
    // AI 颜色评价
    @Published var aiEvaluation: ColorEvaluation? = nil
    
    // 用户输入的感受（发送给 AI 的 message）
    @Published var userMessage: String? = nil
    
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
struct ColorEvaluation: Codable {
    var isLoading: Bool = false
    var error: String? = nil
    var completedAt: Date? = nil
    
    // 整体评价
    var overallEvaluation: OverallEvaluation? = nil
    
    // 各簇评价
    var clusterEvaluations: [ClusterEvaluation] = []
}

// MARK: - 整体评价
struct OverallEvaluation: Codable {
    var hueAnalysis: String  // 色调分析
    var saturationAnalysis: String  // 饱和度分析
    var brightnessAnalysis: String  // 明度分析
    var fullText: String  // 完整评价文本
}

// MARK: - 单簇评价
struct ClusterEvaluation: Identifiable, Codable {
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
    let medianLightness: Float
    
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

// MARK: - 色偏分析结果
struct ColorCastResult: Codable {
    let rms: Float              // RMS 对比度
    
    // 高光区域色偏
    let highlightAMean: Float   // 高光区域 Lab a 通道均值
    let highlightBMean: Float   // 高光区域 Lab b 通道均值
    let highlightCast: Float    // 高光区域偏色强度
    let highlightHueDegrees: Float  // 高光区域色偏方向（0-360°）
    
    // 阴影区域色偏
    let shadowAMean: Float      // 阴影区域 Lab a 通道均值
    let shadowBMean: Float      // 阴影区域 Lab b 通道均值
    let shadowCast: Float       // 阴影区域偏色强度
    let shadowHueDegrees: Float // 阴影区域色偏方向（0-360°）
    
    // 兼容性字段（保留旧版本，使用高光+阴影的平均值）
    var aMean: Float {
        (highlightAMean + shadowAMean) / 2.0
    }
    var bMean: Float {
        (highlightBMean + shadowBMean) / 2.0
    }
    var cast: Float {
        (highlightCast + shadowCast) / 2.0
    }
    var hueAngleDegrees: Float {
        // 使用向量平均的方式计算平均色相
        let avgA = aMean
        let avgB = bMean
        let hue = atan2(avgB, avgA) * 180.0 / Float.pi
        return hue >= 0 ? hue : hue + 360
    }
}

// MARK: - 高级色彩分析（Advanced Color Analysis）
struct AdvancedColorAnalysis: Codable {
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
    
    // 色偏分析结果
    var colorCastResult: ColorCastResult? = nil  // 色偏分析数据
}

// MARK: - 类型别名（向后兼容）
typealias WarmCoolScore = AdvancedColorAnalysis

// MARK: - 风格分析辅助数据

/// SLIC 分析数据（用于风格分析）
struct SLICAnalysisData: Codable {
    let labBuffer: [Float]
    let labels: [Int]
    let width: Int
    let height: Int
}

/// HSL 分析数据（用于风格分析）
struct HSLAnalysisData: Codable {
    // 将 tuple 改为结构体以支持 Codable
    struct HSLValue: Codable {
        let h: Float
        let s: Float
        let l: Float
    }
    
    let hslList: [HSLValue]
    
    // 便捷初始化器（从 tuple 数组）
    init(hslList: [(h: Float, s: Float, l: Float)]) {
        self.hslList = hslList.map { HSLValue(h: $0.h, s: $0.s, l: $0.l) }
    }
    
    // 便捷访问（返回 tuple 数组）
    var tuples: [(h: Float, s: Float, l: Float)] {
        hslList.map { ($0.h, $0.s, $0.l) }
    }
}

// MARK: - 所有照片的冷暖分布数据
struct WarmCoolDistribution {
    var scores: [String: AdvancedColorAnalysis]  // assetIdentifier -> score
    var histogram: [Float]                // 直方图数据（分档统计）
    var histogramBins: Int = 20           // 直方图分档数
    var minScore: Float = -1.0
    var maxScore: Float = 1.0
}

// MARK: - Vision 识别信息
struct PhotoVisionInfo: Codable {
    // 场景识别
    var sceneClassifications: [SceneClassification] = []
    
    // 显著性分析（主体位置）
    var saliencyObjects: [SaliencyObject] = []
    
    // 图像分类标签
    var imageClassifications: [ImageClassification] = []
    
    // 对象检测
    var recognizedObjects: [RecognizedObject] = []
    
    // 地平线检测
    var horizonAngle: Float? = nil
    var horizonTransform: String? = nil
    
    // 分析时间戳
    var analyzedAt: Date = Date()
    
    // 摄影相关属性推断
    var photographyAttributes: PhotographyAttributes? = nil
}

// MARK: - Vision 子结构

/// 场景分类结果
struct SceneClassification: Codable, Identifiable {
    var id: String { identifier }
    var identifier: String  // 场景标识符（如 "beach", "sunset"）
    var confidence: Float   // 置信度 0-1
}

/// 显著性对象（主体位置）
struct SaliencyObject: Codable, Identifiable {
    var id = UUID()
    var boundingBox: CGRect  // 归一化坐标 (0-1)
    var confidence: Float
}

/// 图像分类标签
struct ImageClassification: Codable, Identifiable {
    var id: String { identifier }
    var identifier: String  // 分类标识符
    var confidence: Float
}

// 识别的对象（对象检测）
struct RecognizedObject: Codable, Identifiable {
    var id = UUID()
    var identifier: String  // 对象标识符（如 "dog", "cat"）
    var confidence: Float   // 置信度 0-1
    var boundingBox: CGRect // 归一化坐标 (0-1)
}

/// 摄影属性推断
struct PhotographyAttributes: Codable {
    var hasHorizon: Bool = false
    var horizonTilt: Float? = nil  // 倾斜角度（弧度）
    var compositionType: String? = nil  // 构图类型（基于显著性分析）
    var subjectCount: Int = 0  // 主体数量
    var sceneType: String? = nil  // 场景类型（最高置信度）
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

