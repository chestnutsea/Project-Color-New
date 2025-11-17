//
//  CollectionFeatureCalculator.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/17.
//  作品集特征聚合计算器
//

import Foundation

/// 作品集特征聚合计算器
class CollectionFeatureCalculator {
    
    /// 从多张图片的 ImageFeature 聚合出 CollectionFeature
    /// - Parameters:
    ///   - imageFeatures: 所有图片的特征
    ///   - globalPalette: 全局调色板（来自聚类结果）
    /// - Returns: 作品集特征
    func aggregateCollectionFeature(
        imageFeatures: [ImageFeature],
        globalPalette: [ColorCluster]
    ) -> CollectionFeature {
        
        guard !imageFeatures.isEmpty else {
            return createEmptyFeature()
        }
        
        // 1. 光线特征聚合
        let brightnessDistribution = findMode(imageFeatures.map { $0.brightness })
        let contrastDistribution = findMode(imageFeatures.map { $0.contrast })
        let dynamicRangeDistribution = findMode(imageFeatures.map { $0.dynamicRange })
        let lightDirectionStats = calculateLightDirectionStats(imageFeatures: imageFeatures)
        
        // 2. 色彩特征聚合
        let meanCoolWarmScore = imageFeatures.map { $0.coolWarmScore }.reduce(0, +) / Float(imageFeatures.count)
        let saturationDistribution = findMode(imageFeatures.map { $0.saturationLevel })
        let colorVariety = findMode(imageFeatures.map { $0.colorVariety })
        
        // 3. 转换全局调色板
        let namedPalette = globalPalette.map { cluster in
            StyleColor(
                name: cluster.colorName,
                ratio: Float(cluster.photoCount) / Float(imageFeatures.count)
            )
        }
        
        // 4. 聚合情绪标签
        let aggregatedMoodTags = aggregateMoodTags(imageFeatures: imageFeatures)
        
        // 5. 生成风格标签
        let styleTags = generateStyleTags(
            brightnessDistribution: brightnessDistribution,
            contrastDistribution: contrastDistribution,
            saturationDistribution: saturationDistribution,
            meanCoolWarmScore: meanCoolWarmScore,
            colorVariety: colorVariety
        )
        
        return CollectionFeature(
            brightnessDistribution: brightnessDistribution,
            contrastDistribution: contrastDistribution,
            dynamicRangeDistribution: dynamicRangeDistribution,
            lightDirectionStats: lightDirectionStats,
            meanCoolWarmScore: meanCoolWarmScore,
            saturationDistribution: saturationDistribution,
            colorVariety: colorVariety,
            globalPalette: namedPalette,
            aggregatedMoodTags: aggregatedMoodTags,
            styleTags: styleTags
        )
    }
    
    // MARK: - 众数计算
    
    /// 找到数组中的众数（出现最多的元素）
    private func findMode<T: Hashable>(_ values: [T]) -> T {
        var counts: [T: Int] = [:]
        for value in values {
            counts[value, default: 0] += 1
        }
        
        return counts.max(by: { $0.value < $1.value })?.key ?? values.first!
    }
    
    // MARK: - 光线方向统计
    
    /// 计算光线方向统计
    private func calculateLightDirectionStats(imageFeatures: [ImageFeature]) -> [String: Float] {
        var counts: [String: Int] = [:]
        var total = 0
        
        for feature in imageFeatures {
            if let direction = feature.lightDirection, direction != .unknown {
                counts[direction.rawValue, default: 0] += 1
                total += 1
            }
        }
        
        var stats: [String: Float] = [:]
        for (direction, count) in counts {
            stats[direction] = Float(count) / Float(max(1, total))
        }
        
        return stats
    }
    
    // MARK: - 情绪标签聚合
    
    /// 聚合情绪标签（加权平均）
    private func aggregateMoodTags(imageFeatures: [ImageFeature]) -> [String: Float] {
        var totalWeights: [String: Float] = [:]
        
        for feature in imageFeatures {
            for (tag, weight) in feature.moodTags {
                totalWeights[tag, default: 0] += weight
            }
        }
        
        // 归一化
        let total = totalWeights.values.reduce(0, +)
        if total > 0 {
            for key in totalWeights.keys {
                totalWeights[key] = totalWeights[key]! / total
            }
        }
        
        // 只保留权重 > 0.05 的标签
        return totalWeights.filter { $0.value > 0.05 }
    }
    
    // MARK: - 风格标签生成
    
    /// 生成风格标签（基于规则）
    private func generateStyleTags(
        brightnessDistribution: BrightnessLevel,
        contrastDistribution: ContrastLevel,
        saturationDistribution: SaturationLevel,
        meanCoolWarmScore: Float,
        colorVariety: ColorVarietyLevel
    ) -> [String] {
        
        var tags: [String] = []
        
        // 冷暖倾向
        if meanCoolWarmScore < -0.3 {
            tags.append("cool_toned")
        } else if meanCoolWarmScore > 0.3 {
            tags.append("warm_toned")
        } else {
            tags.append("neutral_toned")
        }
        
        // 饱和度
        if saturationDistribution == .low {
            tags.append("muted_colors")
        } else if saturationDistribution == .high {
            tags.append("vibrant_colors")
        }
        
        // 亮度
        if brightnessDistribution == .low {
            tags.append("low_key")
        } else if brightnessDistribution == .high {
            tags.append("high_key")
        }
        
        // 对比度
        if contrastDistribution == .low {
            tags.append("soft_contrast")
        } else if contrastDistribution == .high {
            tags.append("high_contrast")
        }
        
        // 色彩丰富度
        if colorVariety == .low {
            tags.append("monochromatic")
        } else if colorVariety == .high {
            tags.append("colorful")
        }
        
        // 组合标签
        if saturationDistribution == .low && meanCoolWarmScore < -0.2 {
            tags.append("film_like")
        }
        
        if contrastDistribution == .high && meanCoolWarmScore < -0.2 {
            tags.append("cinematic")
        }
        
        if brightnessDistribution == .high && saturationDistribution == .low {
            tags.append("airy")
        }
        
        return tags
    }
    
    // MARK: - 辅助函数
    
    /// 创建空的作品集特征
    private func createEmptyFeature() -> CollectionFeature {
        return CollectionFeature(
            brightnessDistribution: .medium,
            contrastDistribution: .medium,
            dynamicRangeDistribution: .medium,
            lightDirectionStats: [:],
            meanCoolWarmScore: 0,
            saturationDistribution: .medium,
            colorVariety: .medium,
            globalPalette: [],
            aggregatedMoodTags: [:],
            styleTags: []
        )
    }
}

