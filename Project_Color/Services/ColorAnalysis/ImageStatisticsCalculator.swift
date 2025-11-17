//
//  ImageStatisticsCalculator.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/17.
//  图像统计计算器（用于风格分析）
//

import Foundation
import CoreGraphics
import simd

/// 图像统计计算器
class ImageStatisticsCalculator {
    
    // MARK: - 输入数据结构
    
    /// SLIC 分割数据（从冷暖计算中传递）
    struct SLICData {
        let labBuffer: [Float]      // Lab 数据（L, a, b, L, a, b, ...）
        let labels: [Int]            // 每个像素的超像素标签
        let width: Int
        let height: Int
    }
    
    /// HSL 数据（从冷暖计算中传递）
    struct HSLData {
        let hslList: [(h: Float, s: Float, l: Float)]
    }
    
    // MARK: - 主计算方法
    
    /// 计算图像统计特征
    /// - Parameters:
    ///   - slicData: SLIC 分割数据
    ///   - hslData: HSL 数据
    ///   - dominantColors: 主色数据
    ///   - coolWarmScore: 冷暖分数
    /// - Returns: 图像特征
    func calculateImageFeature(
        slicData: SLICData,
        hslData: HSLData,
        dominantColors: [DominantColor],
        coolWarmScore: Float
    ) -> ImageFeature {
        
        // 1. 计算 Lab L 统计
        let lStats = calculateLStatistics(slicData: slicData)
        
        // 2. 计算 HSL S 统计
        let sStats = calculateSStatistics(hslData: hslData)
        
        // 3. 计算光线方向
        let lightDirection = calculateLightDirection(slicData: slicData)
        
        // 4. 计算阴影/高光比例
        let (shadowRatio, highlightRatio) = calculateShadowHighlightRatio(lStats: lStats)
        
        // 5. 离散化特征
        let brightness = BrightnessLevel.from(lMean: lStats.mean)
        let contrast = ContrastLevel.from(lStd: lStats.std)
        let dynamicRange = DynamicRangeLevel.from(dynamicRange: lStats.dynamicRange)
        let saturationLevel = SaturationLevel.from(sMean: sStats.mean)
        
        // 6. 计算色彩丰富度
        let effectiveColorCount = dominantColors.filter { $0.weight > 0.12 }.count
        let colorVariety = ColorVarietyLevel.from(effectiveColorCount: effectiveColorCount)
        
        // 7. 转换主色为 StyleColor
        let namedColors = dominantColors.map { color in
            StyleColor(name: color.colorName, ratio: color.weight)
        }
        
        // 8. 计算情绪标签
        let moodTags = calculateMoodTags(
            brightness: brightness,
            contrast: contrast,
            saturationLevel: saturationLevel,
            colorVariety: colorVariety,
            coolWarmScore: coolWarmScore,
            lightDirection: lightDirection
        )
        
        // 9. 构建 ImageFeature
        return ImageFeature(
            brightness: brightness,
            contrast: contrast,
            dynamicRange: dynamicRange,
            lightDirection: lightDirection,
            shadowRatio: shadowRatio,
            highlightRatio: highlightRatio,
            coolWarmScore: coolWarmScore,
            saturationLevel: saturationLevel,
            colorVariety: colorVariety,
            dominantColors: namedColors,
            moodTags: moodTags,
            lMean: lStats.mean,
            lStd: lStats.std,
            dynamicRangeValue: lStats.dynamicRange,
            sMean: sStats.mean
        )
    }
    
    // MARK: - Lab L 统计
    
    struct LStatistics {
        let mean: Float
        let std: Float
        let p05: Float
        let p95: Float
        let dynamicRange: Float
        let lValues: [Float]  // 保存用于后续计算
    }
    
    /// 计算 Lab L 统计
    private func calculateLStatistics(slicData: SLICData) -> LStatistics {
        let N = slicData.width * slicData.height
        var lValues: [Float] = []
        lValues.reserveCapacity(N)
        
        // 提取所有 L 值
        for i in 0..<N {
            let idx = i * 3
            let L = slicData.labBuffer[idx]
            lValues.append(L)
        }
        
        // 计算均值
        let sum = lValues.reduce(0, +)
        let mean = sum / Float(N)
        
        // 计算标准差
        let variance = lValues.map { pow($0 - mean, 2) }.reduce(0, +) / Float(N)
        let std = sqrt(variance)
        
        // 计算百分位
        let sortedL = lValues.sorted()
        let p05Index = Int(Float(N) * 0.05)
        let p95Index = Int(Float(N) * 0.95)
        let p05 = sortedL[min(p05Index, N - 1)]
        let p95 = sortedL[min(p95Index, N - 1)]
        let dynamicRange = p95 - p05
        
        return LStatistics(
            mean: mean,
            std: std,
            p05: p05,
            p95: p95,
            dynamicRange: dynamicRange,
            lValues: lValues
        )
    }
    
    // MARK: - HSL S 统计
    
    struct SStatistics {
        let mean: Float
    }
    
    /// 计算 HSL S 统计
    private func calculateSStatistics(hslData: HSLData) -> SStatistics {
        let sValues = hslData.hslList.map { $0.s }
        let sum = sValues.reduce(0, +)
        let mean = sum / Float(max(1, sValues.count))
        
        return SStatistics(mean: mean)
    }
    
    // MARK: - 光线方向计算
    
    /// 计算光线方向（基于 SLIC 超像素）
    private func calculateLightDirection(slicData: SLICData) -> LightDirection {
        let N = slicData.width * slicData.height
        let K = (slicData.labels.max() ?? -1) + 1
        
        if K <= 0 { return .unknown }
        
        // 统计每个超像素的 L 均值和位置
        var sumL = [Float](repeating: 0, count: K)
        var sumX = [Float](repeating: 0, count: K)
        var sumY = [Float](repeating: 0, count: K)
        var count = [Int](repeating: 0, count: K)
        
        for y in 0..<slicData.height {
            for x in 0..<slicData.width {
                let idxPix = y * slicData.width + x
                let k = slicData.labels[idxPix]
                if k < 0 || k >= K { continue }
                
                let labIdx = idxPix * 3
                let L = slicData.labBuffer[labIdx]
                
                sumL[k] += L
                sumX[k] += Float(x)
                sumY[k] += Float(y)
                count[k] += 1
            }
        }
        
        // 找到高光超像素（L > 70）
        var highlightX: Float = 0
        var highlightY: Float = 0
        var highlightCount = 0
        
        for k in 0..<K {
            if count[k] == 0 { continue }
            let meanL = sumL[k] / Float(count[k])
            
            if meanL > 70 {
                let meanX = sumX[k] / Float(count[k])
                let meanY = sumY[k] / Float(count[k])
                highlightX += meanX * Float(count[k])
                highlightY += meanY * Float(count[k])
                highlightCount += count[k]
            }
        }
        
        if highlightCount == 0 { return .unknown }
        
        // 计算高光质心
        let centroidX = highlightX / Float(highlightCount)
        let centroidY = highlightY / Float(highlightCount)
        
        // 相对于图像中心的偏移
        let cx = centroidX - Float(slicData.width) / 2.0
        let cy = centroidY - Float(slicData.height) / 2.0
        
        // 判断方向
        let absX = abs(cx)
        let absY = abs(cy)
        
        if absX > absY {
            // 水平方向主导
            return cx > 0 ? .right : .left
        } else {
            // 垂直方向主导
            if cy < 0 {
                // 上半部分
                return absY > Float(slicData.height) * 0.15 ? .back : .overhead
            } else {
                // 下半部分
                return .front
            }
        }
    }
    
    // MARK: - 阴影/高光比例
    
    /// 计算阴影和高光比例
    private func calculateShadowHighlightRatio(lStats: LStatistics) -> (shadow: Float, highlight: Float) {
        let N = lStats.lValues.count
        
        var shadowCount = 0
        var highlightCount = 0
        
        for L in lStats.lValues {
            if L < 30 {
                shadowCount += 1
            } else if L > 70 {
                highlightCount += 1
            }
        }
        
        let shadowRatio = Float(shadowCount) / Float(N)
        let highlightRatio = Float(highlightCount) / Float(N)
        
        return (shadowRatio, highlightRatio)
    }
    
    // MARK: - 情绪标签计算
    
    /// 计算情绪标签及其权重
    private func calculateMoodTags(
        brightness: BrightnessLevel,
        contrast: ContrastLevel,
        saturationLevel: SaturationLevel,
        colorVariety: ColorVarietyLevel,
        coolWarmScore: Float,
        lightDirection: LightDirection?
    ) -> [String: Float] {
        
        var weights: [String: Float] = [:]
        
        // 1. Quiet（安静）
        let quietWeight =
            max(0, -coolWarmScore) * 0.4 +
            (saturationLevel == .low ? 0.3 : 0) +
            (brightness == .low ? 0.3 : 0.1)
        weights[MoodTags.quiet] = quietWeight
        
        // 2. Calm（平静）
        let calmWeight =
            (colorVariety == .low ? 0.4 : 0.1) +
            (contrast == .low ? 0.4 : 0.1) +
            (brightness == .medium ? 0.2 : 0.1)
        weights[MoodTags.calm] = Float(calmWeight)
        
        // 3. Lonely（孤独）
        let lonelyWeight =
            max(0, -coolWarmScore) * 0.4 +
            (brightness == .low ? 0.4 : 0.1) +
            (saturationLevel == .low ? 0.2 : 0.1)
        weights[MoodTags.lonely] = lonelyWeight
        
        // 4. Nostalgic（怀旧）
        let nostalgicWeight =
            max(0, coolWarmScore) * 0.4 +
            (saturationLevel == .low ? 0.3 : 0.15) +
            (contrast == .low ? 0.3 : 0.1)
        weights[MoodTags.nostalgic] = nostalgicWeight
        
        // 5. Warm（温暖）
        let warmWeight =
            max(0, coolWarmScore) * 0.6 +
            (brightness == .high ? 0.4 : 0.2)
        weights[MoodTags.warm] = warmWeight
        
        // 6. Friendly（亲切感）
        let friendlyWeight =
            max(0, coolWarmScore) * 0.4 +
            (brightness == .medium ? 0.3 : 0.1) +
            (saturationLevel == .medium ? 0.3 : 0.1)
        weights[MoodTags.friendly] = friendlyWeight
        
        // 7. Cinematic（电影感）
        let cinematicWeight =
            max(0, -coolWarmScore) * 0.4 +
            (contrast == .high ? 0.4 : 0.1) +
            (brightness != .high ? 0.2 : 0)
        weights[MoodTags.cinematic] = cinematicWeight
        
        // 8. Dramatic（戏剧性）
        let dramaticWeight =
            (contrast == .high ? 0.5 : 0.2) +
            (lightDirection == .left || lightDirection == .right ? 0.3 : 0.1) +
            (lightDirection == .back ? 0.2 : 0)
        weights[MoodTags.dramatic] = Float(dramaticWeight)
        
        // 9. Soft（柔和）
        let softWeight =
            (contrast == .low ? 0.6 : 0.2) +
            (brightness == .high ? 0.4 : 0.1)
        weights[MoodTags.soft] = Float(softWeight)
        
        // 10. Muted（压低色彩、克制）
        let mutedWeight =
            (saturationLevel == .low ? 0.7 : 0.2) +
            (abs(coolWarmScore) < 0.3 ? 0.3 : 0.1)
        weights[MoodTags.muted] = Float(mutedWeight)
        
        // 11. Gentle（温柔）
        let gentleWeight =
            (contrast == .low ? 0.4 : 0.1) +
            (saturationLevel == .low ? 0.3 : 0.1) +
            (coolWarmScore > -0.2 ? 0.3 : 0.0)
        weights[MoodTags.gentle] = Float(gentleWeight)
        
        // 12. Vibrant（鲜活）
        let vibrantWeight =
            (saturationLevel == .high ? 0.6 : 0.2) +
            (brightness != .low ? 0.4 : 0.1)
        weights[MoodTags.vibrant] = Float(vibrantWeight)
        
        // 归一化
        let total = weights.values.reduce(0, +)
        if total > 0 {
            for key in weights.keys {
                weights[key] = weights[key]! / total
            }
        }
        
        // 只保留权重 > 0.05 的标签
        return weights.filter { $0.value > 0.05 }
    }
}

