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
        
        // 情绪和风格标签已删除，不再计算
        
        return CollectionFeature(
            brightnessDistribution: brightnessDistribution,
            contrastDistribution: contrastDistribution,
            dynamicRangeDistribution: dynamicRangeDistribution,
            lightDirectionStats: lightDirectionStats,
            meanCoolWarmScore: meanCoolWarmScore,
            saturationDistribution: saturationDistribution,
            colorVariety: colorVariety,
            globalPalette: namedPalette,
            aggregatedMoodTags: [:],  // 已删除，返回空字典
            styleTags: []  // 已删除，返回空数组
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
    
    // MARK: - 情绪和风格标签（已删除）
    
    // 情绪标签和风格标签的计算已删除，不再需要这些方法
    
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

