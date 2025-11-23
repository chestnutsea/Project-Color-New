//
//  StyleAnalysisModels.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/17.
//  风格分析数据模型（基于 SLIC 的扩展分析）
//

import Foundation

// MARK: - 枚举类型

/// 亮度等级
enum BrightnessLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    /// 从 Lab L 均值计算
    static func from(lMean: Float) -> BrightnessLevel {
        if lMean < 35 {
            return .low
        } else if lMean < 65 {
            return .medium
        } else {
            return .high
        }
    }
}

/// 对比度等级
enum ContrastLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    /// 从 Lab L 标准差计算
    static func from(lStd: Float) -> ContrastLevel {
        if lStd < 14 {
            return .low
        } else if lStd < 28 {
            return .medium
        } else {
            return .high
        }
    }
}

/// 动态范围等级
enum DynamicRangeLevel: String, Codable {
    case narrow = "narrow"
    case medium = "medium"
    case wide = "wide"
    
    /// 从动态范围（p95 - p05）计算
    static func from(dynamicRange: Float) -> DynamicRangeLevel {
        if dynamicRange < 30 {
            return .narrow
        } else if dynamicRange < 55 {
            return .medium
        } else {
            return .wide
        }
    }
}

/// 饱和度等级
enum SaturationLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    /// 从 HSL S 均值计算
    static func from(sMean: Float) -> SaturationLevel {
        if sMean < 0.18 {
            return .low
        } else if sMean < 0.35 {
            return .medium
        } else {
            return .high
        }
    }
}

/// 色彩丰富度等级
enum ColorVarietyLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    /// 从有效主色数量计算
    static func from(effectiveColorCount: Int) -> ColorVarietyLevel {
        if effectiveColorCount <= 1 {
            return .low
        } else if effectiveColorCount <= 4 {
            return .medium
        } else {
            return .high
        }
    }
}

/// 光线方向
enum LightDirection: String, Codable {
    case left = "left"
    case right = "right"
    case back = "back"
    case overhead = "overhead"
    case front = "front"
    case unknown = "unknown"
}

// MARK: - 命名颜色（用于 LLM 输入）

/// 简化的颜色信息（用于风格分析和 LLM 输入）
struct StyleColor: Codable {
    let name: String
    let ratio: Float
}

// MARK: - 单张图片特征

/// 单张图片的中层特征（离散化后的语义特征）
struct ImageFeature: Codable {
    // MARK: - 光线特征
    
    /// 亮度等级
    var brightness: BrightnessLevel
    
    /// 对比度等级
    var contrast: ContrastLevel
    
    /// 动态范围等级
    var dynamicRange: DynamicRangeLevel
    
    /// 光线方向（可选）
    var lightDirection: LightDirection?
    
    /// 阴影比例（0-1）
    var shadowRatio: Float
    
    /// 高光比例（0-1）
    var highlightRatio: Float
    
    // MARK: - 色彩特征
    
    /// 冷暖分数（-1 到 1）
    var coolWarmScore: Float
    
    /// 饱和度等级
    var saturationLevel: SaturationLevel
    
    /// 色彩丰富度等级
    var colorVariety: ColorVarietyLevel
    
    /// 主色（名称 + 占比）
    var dominantColors: [StyleColor]
    
    // MARK: - 情绪特征
    
    /// 情绪标签及其权重（归一化后的）
    var moodTags: [String: Float]
    
    // MARK: - 原始统计数据（用于调试）
    
    /// Lab L 均值
    var lMean: Float
    
    /// Lab L 标准差
    var lStd: Float
    
    /// 动态范围（p95 - p05）
    var dynamicRangeValue: Float
    
    /// HSL S 均值
    var sMean: Float
}

// MARK: - 作品集聚合特征

/// 作品集的聚合特征（多张图片的整体统计）
struct CollectionFeature: Codable {
    // MARK: - 光线整体统计
    
    /// 亮度分布（众数）
    var brightnessDistribution: BrightnessLevel
    
    /// 对比度分布（众数）
    var contrastDistribution: ContrastLevel
    
    /// 动态范围分布（众数）
    var dynamicRangeDistribution: DynamicRangeLevel
    
    /// 光线方向统计（各方向的占比）
    var lightDirectionStats: [String: Float]
    
    // MARK: - 色彩整体统计
    
    /// 平均冷暖分数
    var meanCoolWarmScore: Float
    
    /// 饱和度分布（众数）
    var saturationDistribution: SaturationLevel
    
    /// 色彩丰富度（众数）
    var colorVariety: ColorVarietyLevel
    
    /// 全局调色板（来自聚类结果）
    var globalPalette: [StyleColor]
    
    // MARK: - 情绪分布
    
    /// 聚合的情绪标签（加权平均）
    var aggregatedMoodTags: [String: Float]
    
    // MARK: - 风格标签
    
    /// 算法生成的风格标签
    var styleTags: [String]
    
    // MARK: - 转换为 JSON（用于 LLM 输入）
    
    /// 转换为适合 LLM 的 JSON 字符串
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(self),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    /// 转换为适合 LLM 的字典（用于 Prompt）
    func toDictionary() -> [String: Any] {
        return [
            "brightness_distribution": brightnessDistribution.rawValue,
            "contrast_distribution": contrastDistribution.rawValue,
            "dynamic_range_distribution": dynamicRangeDistribution.rawValue,
            "light_direction_stats": lightDirectionStats,
            "mean_cool_warm_score": meanCoolWarmScore,
            "saturation_distribution": saturationDistribution.rawValue,
            "color_variety": colorVariety.rawValue,
            "global_palette": globalPalette.map { ["name": $0.name, "ratio": $0.ratio] }
            // 情绪和风格标签已删除，不再包含在字典中
        ]
    }
}

// MARK: - 情绪标签常量

/// 情绪标签定义（12 个常用摄影情绪关键词）
struct MoodTags {
    static let quiet = "quiet"
    static let calm = "calm"
    static let lonely = "lonely"
    static let nostalgic = "nostalgic"
    static let warm = "warm"
    static let friendly = "friendly"
    static let cinematic = "cinematic"
    static let dramatic = "dramatic"
    static let soft = "soft"
    static let muted = "muted"
    static let gentle = "gentle"
    static let vibrant = "vibrant"
    
    /// 所有情绪标签
    static let all = [
        quiet, calm, lonely,
        nostalgic, warm, friendly,
        cinematic, dramatic,
        soft, muted, gentle,
        vibrant
    ]
}

