//
//  ColorStatisticsCalculator.swift
//  Project_Color
//
//  色彩统计计算器 - 按需计算聚类和全局统计数据
//

import Foundation

/// 色彩统计计算器
class ColorStatisticsCalculator {
    
    private let colorConverter = ColorSpaceConverter()
    
    // MARK: - 公开接口
    
    /// 计算全局色彩统计
    func calculateGlobalStatistics(result: AnalysisResult) -> GlobalColorStatistics {
        let allPhotos = result.photoInfos
        
        // 收集所有照片的代表色
        var allHues: [Float] = []
        var allLightness: [Float] = []
        var allSaturation: [Float] = []
        var totalWeight: Float = 0
        
        for photo in allPhotos {
            guard let repColor = photo.dominantColors.first else { continue }
            let weight = repColor.weight
            
            // 从 RGB 转换到 HSL
            let hsl = rgbToHSL(repColor.rgb)
            
            allHues.append(hsl.h)
            allLightness.append(hsl.l * weight)
            allSaturation.append(hsl.s * weight)
            totalWeight += weight
        }
        
        // 计算平均值
        let avgLightness = totalWeight > 0 ? allLightness.reduce(0, +) / totalWeight : 0
        let avgSaturation = totalWeight > 0 ? allSaturation.reduce(0, +) / totalWeight : 0
        
        // 分析色相分布
        let hueDistribution = analyzeHueDistribution(hues: allHues)
        let dominantHueRange = determineDominantHueRange(distribution: hueDistribution)
        
        // 分析明度分布
        let lightnessDistribution = analyzeLightnessDistribution(lightness: allLightness)
        let dominantValue = determineDominantValue(avgLightness: avgLightness)
        
        // 分析饱和度分布
        let saturationDistribution = analyzeSaturationDistribution(saturation: allSaturation)
        let dominantSaturation = determineDominantSaturation(avgSaturation: avgSaturation)
        
        return GlobalColorStatistics(
            dominantHueRange: dominantHueRange,
            dominantValue: dominantValue,
            averageLightness: avgLightness,
            dominantSaturation: dominantSaturation,
            averageSaturation: avgSaturation,
            hueDistribution: hueDistribution,
            lightnessDistribution: lightnessDistribution,
            saturationDistribution: saturationDistribution
        )
    }
    
    /// 计算所有聚类的统计数据
    func calculateClusterAnalytics(result: AnalysisResult) -> [ClusterAnalytics] {
        var analytics: [ClusterAnalytics] = []
        
        for cluster in result.clusters {
            let photos = result.photos(in: cluster.index)
            let statistics = calculateClusterStatistics(photos: photos)
            
            analytics.append(ClusterAnalytics(
                cluster: cluster,
                statistics: statistics
            ))
        }
        
        return analytics
    }
    
    // MARK: - 聚类统计
    
    /// 计算单个聚类的统计数据
    private func calculateClusterStatistics(photos: [PhotoColorInfo]) -> ClusterStatistics {
        guard !photos.isEmpty else {
            return ClusterStatistics(
                hueRange: (0, 0),
                hueStdDev: 0,
                lightnessRange: (0, 0),
                lightnessStdDev: 0,
                saturationRange: (0, 0),
                saturationStdDev: 0,
                consistency: 0,
                photoCount: 0
            )
        }
        
        // 收集所有照片的代表色数据
        var hues: [Float] = []
        var lightness: [Float] = []
        var saturation: [Float] = []
        
        for photo in photos {
            guard let repColor = photo.dominantColors.first else { continue }
            
            // 从 RGB 转换到 HSL
            let hsl = rgbToHSL(repColor.rgb)
            
            hues.append(hsl.h)
            lightness.append(hsl.l)
            saturation.append(hsl.s)
        }
        
        // 计算范围
        let hueRange = (min: hues.min() ?? 0, max: hues.max() ?? 0)
        let lightnessRange = (min: lightness.min() ?? 0, max: lightness.max() ?? 0)
        let saturationRange = (min: saturation.min() ?? 0, max: saturation.max() ?? 0)
        
        // 计算标准差
        let hueStdDev = standardDeviation(values: hues)
        let lightnessStdDev = standardDeviation(values: lightness)
        let saturationStdDev = standardDeviation(values: saturation)
        
        // 计算一致性（基于标准差的倒数，归一化到 0-1）
        let avgStdDev = (hueStdDev / 360.0 + lightnessStdDev + saturationStdDev) / 3.0
        let consistency = max(0, 1.0 - avgStdDev)
        
        return ClusterStatistics(
            hueRange: hueRange,
            hueStdDev: hueStdDev,
            lightnessRange: lightnessRange,
            lightnessStdDev: lightnessStdDev,
            saturationRange: saturationRange,
            saturationStdDev: saturationStdDev,
            consistency: consistency,
            photoCount: photos.count
        )
    }
    
    // MARK: - 色相分布分析
    
    /// 分析色相分布
    private func analyzeHueDistribution(hues: [Float]) -> [(range: String, percentage: Float)] {
        guard !hues.isEmpty else { return [] }
        
        // 定义色相区间
        let hueRanges: [(name: String, min: Float, max: Float)] = [
            ("红色系", 345, 15),
            ("橙色系", 15, 45),
            ("黄色系", 45, 75),
            ("黄绿色系", 75, 105),
            ("绿色系", 105, 165),
            ("青色系", 165, 195),
            ("蓝色系", 195, 255),
            ("紫色系", 255, 285),
            ("品红色系", 285, 345)
        ]
        
        var distribution: [(range: String, percentage: Float)] = []
        let totalCount = Float(hues.count)
        
        for range in hueRanges {
            let count = hues.filter { hue in
                if range.min > range.max {
                    // 跨越 0° 的情况（如红色）
                    return hue >= range.min || hue <= range.max
                } else {
                    return hue >= range.min && hue < range.max
                }
            }.count
            
            let percentage = Float(count) / totalCount
            if percentage > 0.05 {  // 只保留占比 > 5% 的
                distribution.append((range: range.name, percentage: percentage))
            }
        }
        
        // 按占比排序
        distribution.sort { $0.percentage > $1.percentage }
        
        return distribution
    }
    
    /// 确定主导色相范围
    private func determineDominantHueRange(distribution: [(range: String, percentage: Float)]) -> String {
        if distribution.isEmpty {
            return "多色混合"
        }
        
        if distribution.count == 1 {
            return distribution[0].range
        }
        
        // 取前两个主要色相
        let top2 = distribution.prefix(2)
        return top2.map { $0.range }.joined(separator: "-")
    }
    
    // MARK: - 明度分布分析
    
    /// 分析明度分布
    private func analyzeLightnessDistribution(lightness: [Float]) -> [(range: String, percentage: Float)] {
        guard !lightness.isEmpty else { return [] }
        
        let ranges: [(name: String, min: Float, max: Float)] = [
            ("极暗", 0, 0.2),
            ("暗", 0.2, 0.4),
            ("中", 0.4, 0.6),
            ("亮", 0.6, 0.8),
            ("极亮", 0.8, 1.0)
        ]
        
        return analyzeDistribution(values: lightness, ranges: ranges)
    }
    
    /// 确定主导明度
    private func determineDominantValue(avgLightness: Float) -> String {
        if avgLightness < 0.35 {
            return "低调"
        } else if avgLightness < 0.65 {
            return "中调"
        } else {
            return "高调"
        }
    }
    
    // MARK: - 饱和度分布分析
    
    /// 分析饱和度分布
    private func analyzeSaturationDistribution(saturation: [Float]) -> [(range: String, percentage: Float)] {
        guard !saturation.isEmpty else { return [] }
        
        let ranges: [(name: String, min: Float, max: Float)] = [
            ("灰调", 0, 0.2),
            ("柔和", 0.2, 0.5),
            ("鲜艳", 0.5, 0.8),
            ("极艳", 0.8, 1.0)
        ]
        
        return analyzeDistribution(values: saturation, ranges: ranges)
    }
    
    /// 确定主导饱和度
    private func determineDominantSaturation(avgSaturation: Float) -> String {
        if avgSaturation < 0.25 {
            return "灰调"
        } else if avgSaturation < 0.6 {
            return "柔和"
        } else {
            return "艳丽"
        }
    }
    
    // MARK: - 通用辅助函数
    
    /// 通用分布分析
    private func analyzeDistribution(
        values: [Float],
        ranges: [(name: String, min: Float, max: Float)]
    ) -> [(range: String, percentage: Float)] {
        guard !values.isEmpty else { return [] }
        
        var distribution: [(range: String, percentage: Float)] = []
        let totalCount = Float(values.count)
        
        for range in ranges {
            let count = values.filter { $0 >= range.min && $0 < range.max }.count
            let percentage = Float(count) / totalCount
            
            if percentage > 0.05 {  // 只保留占比 > 5% 的
                distribution.append((range: range.name, percentage: percentage))
            }
        }
        
        // 按占比排序
        distribution.sort { $0.percentage > $1.percentage }
        
        return distribution
    }
    
    /// 计算标准差
    private func standardDeviation(values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Float(values.count)
        
        return sqrt(variance)
    }
    
    /// RGB 转 HSL
    private func rgbToHSL(_ rgb: SIMD3<Float>) -> (h: Float, s: Float, l: Float) {
        let r = rgb.x
        let g = rgb.y
        let b = rgb.z
        
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        // Lightness (0-1)
        let l = (maxC + minC) / 2.0
        
        // Saturation (0-1)
        var s: Float = 0
        if delta > 0.00001 {
            s = delta / (1 - abs(2 * l - 1))
        }
        
        // Hue (0-360)
        var h: Float = 0
        if delta > 0.00001 {
            if maxC == r {
                h = 60 * fmod((g - b) / delta, 6)
            } else if maxC == g {
                h = 60 * ((b - r) / delta + 2)
            } else {
                h = 60 * ((r - g) / delta + 4)
            }
        }
        
        if h < 0 {
            h += 360
        }
        
        return (h: h, s: s, l: l)
    }
}

