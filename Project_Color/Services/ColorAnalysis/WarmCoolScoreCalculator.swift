//
//  WarmCoolScoreCalculator.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/16.
//  冷暖色调评分计算器（SLIC-based 新算法）
//

import Foundation
import CoreGraphics
import Accelerate
import simd
#if canImport(UIKit)
import UIKit
#endif

/// 冷暖色调评分计算器
class WarmCoolScoreCalculator {
    
    private let colorConverter = ColorSpaceConverter()
    
    // MARK: - SLIC 配置参数（优化版）
    
    /// 图像最大尺寸（宽或高）
    private let maxDimension: Int = 512
    
    /// 超像素数量（优化：从 200 降到 150）
    private let numSegments: Int = 150
    
    /// SLIC 紧凑度参数
    private let compactness: Float = 20.0
    
    /// SLIC 迭代次数（优化：从 5 降到 3）
    private let maxIterations: Int = 3
    
    /// b* 值归一化缩放因子（统一使用 80.0）
    private let warmScale: Float = 80.0
    
    // MARK: - 权重配置
    
    /// 局部结构（SLIC）权重
    private let localWeight: Float = 0.7
    
    /// 代表色（全局调性）权重
    private let paletteWeight: Float = 0.3
    
    // MARK: - 主入口：计算单张照片的冷暖评分
    
    /// 为单张照片计算完整的冷暖评分（新算法：SLIC + 代表色融合）
    func calculateScore(
        image: CGImage,
        dominantColors: [DominantColor]
    ) async -> WarmCoolScore {
        
        #if DEBUG
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🌡️ 冷暖评分（SLIC-based 新算法）")
        #endif
        
        // 1. Resize 图像
        guard let resizedImage = resizeImage(cgImage: image, maxDimension: maxDimension) else {
            #if DEBUG
            print("❌ 图像 resize 失败")
            #endif
            return createEmptyScore()
        }
        
        let width = resizedImage.width
        let height = resizedImage.height
        
        #if DEBUG
        print("📐 图像尺寸: \(width) × \(height)")
        #endif
        
        // 2. 转换为 Lab buffer（同时计算 HSL）
        guard let (labBuffer, hslList) = createLabBufferWithHSL(from: resizedImage) else {
            #if DEBUG
            print("❌ Lab/HSL 转换失败")
            #endif
            return createEmptyScore()
        }
        
        // 3. SLIC 超像素分割
        #if DEBUG
        print("🔬 SLIC 超像素分割...")
        print("   - 超像素数量: \(numSegments)")
        print("   - 迭代次数: \(maxIterations)")
        #endif
        
        let labels = slicSegmentation(
            labBuffer: labBuffer,
            width: width,
            height: height,
            numSegments: numSegments,
            compactness: compactness,
            maxIterations: maxIterations
        )
        
        // 4. 计算局部结构冷暖（SLIC-based）
        let localScore = computeLocalWarmScore(
            labBuffer: labBuffer,
            labels: labels,
            width: width,
            height: height
        )
        
        #if DEBUG
        print("  🔵 局部结构冷暖: \(String(format: "%.3f", localScore))")
        #endif
        
        // 5. 计算代表色冷暖（全局调性）
        let paletteScore = computePaletteWarmScore(dominantColors: dominantColors)
        
        #if DEBUG
        print("  🎨 代表色冷暖: \(String(format: "%.3f", paletteScore))")
        #endif
        
        // 6. 融合得到最终分数
        let finalScore = localWeight * localScore + paletteWeight * paletteScore
        
        #if DEBUG
        print("  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  📊 融合结果 (\(String(format: "%.0f%%", localWeight * 100))局部 + \(String(format: "%.0f%%", paletteWeight * 100))代表色):")
        print("     最终分数: \(String(format: "%.3f", finalScore)) (\(finalScore > 0 ? "暖调" : finalScore < 0 ? "冷调" : "中性"))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        #endif
        
        // 7. 保存 SLIC 和 HSL 数据（用于后续风格分析）
        let slicData = SLICAnalysisData(
            labBuffer: labBuffer,
            labels: labels,
            width: width,
            height: height
        )
        
        let hslData = HSLAnalysisData(hslList: hslList)
        
        // 8. 构建返回结果
        return WarmCoolScore(
            overallScore: finalScore,        // 最终融合分数
            labBScore: localScore,           // 局部结构分数
            dominantWarmth: paletteScore,    // 代表色分数
            hueWarmth: 0,                    // 已废弃
            warmPixelRatio: 0,               // 已废弃
            coolPixelRatio: 0,               // 已废弃
            neutralPixelRatio: 0,            // 已废弃
            labBMean: localScore,            // 保持兼容性
            overallWarmth: max(0, paletteScore),   // 调试用
            overallCoolness: max(0, -paletteScore), // 调试用
            slicData: slicData,              // SLIC 数据
            hslData: hslData                 // HSL 数据
        )
    }
    
    // MARK: - 图像预处理
    
    /// Resize 图像到指定最大尺寸
    private func resizeImage(cgImage: CGImage, maxDimension: Int) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        let maxSide = max(width, height)
        
        // 如果已经小于目标尺寸，直接返回
        if maxSide <= maxDimension {
            return cgImage
        }
        
        // 计算缩放比例
        let scale = CGFloat(maxDimension) / CGFloat(maxSide)
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)
        
        // 创建新的 context
        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        
        // 绘制缩放后的图像
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context.makeImage()
    }
    
    // MARK: - Lab 和 HSL 转换
    
    /// 创建 Lab buffer 和 HSL 列表（同时计算，避免重复遍历）
    private func createLabBufferWithHSL(from cgImage: CGImage) -> ([Float], [(h: Float, s: Float, l: Float)])? {
        let width = cgImage.width
        let height = cgImage.height
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = bytesPerRow * height
        
        var rawData = [UInt8](repeating: 0, count: totalBytes)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var labBuffer = [Float](repeating: 0, count: width * height * 3)
        var hslList: [(h: Float, s: Float, l: Float)] = []
        hslList.reserveCapacity(width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * bytesPerRow + x * bytesPerPixel
                let r = Float(rawData[byteIndex + 0]) / 255.0
                let g = Float(rawData[byteIndex + 1]) / 255.0
                let b = Float(rawData[byteIndex + 2]) / 255.0
                
                // 计算 Lab
                let (L, a, bLab) = sRGBToLab(r: r, g: g, b: b)
                let index = (y * width + x) * 3
                labBuffer[index + 0] = L
                labBuffer[index + 1] = a
                labBuffer[index + 2] = bLab
                
                // 计算 HSL
                let hsl = rgbToHSL(r: r, g: g, b: b)
                hslList.append(hsl)
            }
        }
        
        return (labBuffer, hslList)
    }
    
    /// 创建 Lab buffer（格式：[L, a, b, L, a, b, ...]）- 保留用于兼容
    private func createLabBuffer(from cgImage: CGImage) -> [Float]? {
        let width = cgImage.width
        let height = cgImage.height
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = bytesPerRow * height
        
        var rawData = [UInt8](repeating: 0, count: totalBytes)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var labBuffer = [Float](repeating: 0, count: width * height * 3)
        
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * bytesPerRow + x * bytesPerPixel
                let r = Float(rawData[byteIndex + 0]) / 255.0
                let g = Float(rawData[byteIndex + 1]) / 255.0
                let b = Float(rawData[byteIndex + 2]) / 255.0
                
                let (L, a, bLab) = sRGBToLab(r: r, g: g, b: b)
                let index = (y * width + x) * 3
                labBuffer[index + 0] = L
                labBuffer[index + 1] = a
                labBuffer[index + 2] = bLab
            }
        }
        
        return labBuffer
    }
    
    /// sRGB 转 Lab（标准转换）
    private func sRGBToLab(r: Float, g: Float, b: Float) -> (Float, Float, Float) {
        func pivotRGB(_ c: Float) -> Float {
            return (c <= 0.04045) ? (c / 12.92) : powf((c + 0.055) / 1.055, 2.4)
        }
        
        let R = pivotRGB(r)
        let G = pivotRGB(g)
        let B = pivotRGB(b)
        
        let X = (0.4124564 * R + 0.3575761 * G + 0.1804375 * B) / 0.95047
        let Y = (0.2126729 * R + 0.7151522 * G + 0.0721750 * B) / 1.00000
        let Z = (0.0193339 * R + 0.1191920 * G + 0.9503041 * B) / 1.08883
        
        func f(_ t: Float) -> Float {
            return (t > 0.008856) ? powf(t, 1.0/3.0) : (7.787 * t + 16.0/116.0)
        }
        
        let fx = f(X)
        let fy = f(Y)
        let fz = f(Z)
        
        let L = max(0, min(100, (116 * fy - 16)))
        let a = 500 * (fx - fy)
        let bLab = 200 * (fy - fz)
        
        return (L, a, bLab)
    }
    
    // MARK: - SLIC 超像素分割
    
    /// SLIC 超像素分割（简化版，优化性能）
    private func slicSegmentation(
        labBuffer: [Float],
        width: Int,
        height: Int,
        numSegments: Int,
        compactness: Float,
        maxIterations: Int
    ) -> [Int] {
        
        let N = width * height
        let S = sqrt(Float(N) / Float(numSegments))  // 初始网格间距
        
        // 初始化 cluster centers
        var centers: [(x: Float, y: Float, L: Float, a: Float, b: Float)] = []
        var labels = [Int](repeating: -1, count: N)
        var distances = [Float](repeating: Float.greatestFiniteMagnitude, count: N)
        
        let step = Int(S)
        for y in stride(from: step/2, to: height, by: step) {
            for x in stride(from: step/2, to: width, by: step) {
                let idx = (y * width + x) * 3
                let L = labBuffer[idx]
                let a = labBuffer[idx + 1]
                let b = labBuffer[idx + 2]
                centers.append((x: Float(x), y: Float(y), L: L, a: a, b: b))
            }
        }
        
        let K = centers.count
        let m = compactness
        
        #if DEBUG
        print("   - 实际超像素数: \(K)")
        #endif
        
        // 迭代优化
        for iteration in 0..<maxIterations {
            // 重置距离
            for i in 0..<N {
                distances[i] = Float.greatestFiniteMagnitude
            }
            
            // 对每个中心在 2S×2S 窗内搜索
            for k in 0..<K {
                let c = centers[k]
                let xStart = max(0, Int(c.x) - step)
                let xEnd = min(width - 1, Int(c.x) + step)
                let yStart = max(0, Int(c.y) - step)
                let yEnd = min(height - 1, Int(c.y) + step)
                
                for y in yStart...yEnd {
                    for x in xStart...xEnd {
                        let idxPix = y * width + x
                        let labIdx = idxPix * 3
                        let L = labBuffer[labIdx]
                        let a = labBuffer[labIdx + 1]
                        let b = labBuffer[labIdx + 2]
                        
                        let dL = L - c.L
                        let da = a - c.a
                        let db = b - c.b
                        let dc = sqrt(dL*dL + da*da + db*db)
                        
                        let dx = Float(x) - c.x
                        let dy = Float(y) - c.y
                        let ds = sqrt(dx*dx + dy*dy)
                        
                        let D = sqrt(dc*dc + (m * ds / S) * (m * ds / S))
                        
                        if D < distances[idxPix] {
                            distances[idxPix] = D
                            labels[idxPix] = k
                        }
                    }
                }
            }
            
            // 更新 centers
            var sumX = [Float](repeating: 0, count: K)
            var sumY = [Float](repeating: 0, count: K)
            var sumL = [Float](repeating: 0, count: K)
            var sumA = [Float](repeating: 0, count: K)
            var sumB = [Float](repeating: 0, count: K)
            var count = [Int](repeating: 0, count: K)
            
            for y in 0..<height {
                for x in 0..<width {
                    let idxPix = y * width + x
                    let k = labels[idxPix]
                    if k < 0 { continue }
                    let labIdx = idxPix * 3
                    let L = labBuffer[labIdx]
                    let a = labBuffer[labIdx + 1]
                    let b = labBuffer[labIdx + 2]
                    
                    sumX[k] += Float(x)
                    sumY[k] += Float(y)
                    sumL[k] += L
                    sumA[k] += a
                    sumB[k] += b
                    count[k] += 1
                }
            }
            
            for k in 0..<K {
                if count[k] == 0 { continue }
                let inv = 1.0 / Float(count[k])
                centers[k].x = sumX[k] * inv
                centers[k].y = sumY[k] * inv
                centers[k].L = sumL[k] * inv
                centers[k].a = sumA[k] * inv
                centers[k].b = sumB[k] * inv
            }
            
            #if DEBUG
            if iteration == maxIterations - 1 {
                print("   - 迭代完成: \(iteration + 1)/\(maxIterations)")
            }
            #endif
        }
        
        return labels
    }
    
    // MARK: - 局部结构冷暖计算（SLIC-based）
    
    /// 计算局部结构冷暖分数（基于 SLIC 超像素）
    private func computeLocalWarmScore(
        labBuffer: [Float],
        labels: [Int],
        width: Int,
        height: Int
    ) -> Float {
        
        let N = width * height
        let K = (labels.max() ?? -1) + 1
        if K <= 0 { return 0 }
        
        // 统计每个 segment 的 L, a, b
        var sumL = [Float](repeating: 0, count: K)
        var sumA = [Float](repeating: 0, count: K)
        var sumB = [Float](repeating: 0, count: K)
        var count = [Int](repeating: 0, count: K)
        
        for i in 0..<N {
            let k = labels[i]
            if k < 0 || k >= K { continue }
            let idx = i * 3
            let L = labBuffer[idx]
            let a = labBuffer[idx + 1]
            let b = labBuffer[idx + 2]
            sumL[k] += L
            sumA[k] += a
            sumB[k] += b
            count[k] += 1
        }
        
        var warmSum: Float = 0
        var weightSum: Float = 0
        var validSegments = 0
        
        for k in 0..<K {
            let c = count[k]
            if c == 0 { continue }
            let inv = 1.0 / Float(c)
            let Lm = sumL[k] * inv
            let am = sumA[k] * inv
            let bm = sumB[k] * inv
            
            // 亮度过滤：极暗/极亮直接忽略
            if Lm < 5 || Lm > 98 { continue }
            
            let C = sqrt(am*am + bm*bm)
            
            // 低饱和区域忽略
            if C < 5 { continue }
            
            // 面积权重
            let areaNorm = Float(c) / Float(N)   // 0~1
            
            // 亮度权重
            let lWeight: Float
            if Lm < 30 {
                lWeight = 0.6
            } else if Lm > 70 {
                lWeight = 1.2
            } else {
                lWeight = 1.0
            }
            
            // 色度权重
            let cWeight: Float
            if C < 15 {
                cWeight = 0.5
            } else if C > 40 {
                cWeight = 0.7
            } else {
                cWeight = 1.0
            }
            
            // 绿色降权
            var greenWeight: Float = 1.0
            if am < -5 && bm > 5 && Lm < 75 {
                greenWeight = 0.5
            }
            
            let weight = areaNorm * lWeight * cWeight * greenWeight
            warmSum += bm * weight
            weightSum += weight
            validSegments += 1
        }
        
        #if DEBUG
        print("   - 有效 segment: \(validSegments)/\(K)")
        #endif
        
        guard weightSum > 0 else { return 0 }
        
        let avgB = warmSum / weightSum   // 大致在 [-100, 100]
        
        // 归一化到 [-1,1]
        let raw = max(-warmScale, min(warmScale, avgB))
        let score = raw / warmScale
        
        return score
    }
    
    // MARK: - 代表色冷暖计算（全局调性）
    
    /// 计算代表色冷暖分数（基于已提取的主色）
    private func computePaletteWarmScore(dominantColors: [DominantColor]) -> Float {
        var warmSum: Float = 0
        var weightSum: Float = 0
        
        #if DEBUG
        print("  🎨 代表色分析 (共 \(dominantColors.count) 个):")
        #endif
        
        for color in dominantColors {
            // RGB → Lab
            let (L, a, bLab) = sRGBToLab(r: color.rgb.x, g: color.rgb.y, b: color.rgb.z)
            let C = sqrtf(a * a + bLab * bLab)
            
            // 低饱和颜色（比如灰色）忽略
            if C < 8 { continue }
            
            // 超高亮/过亮不参与（避免高光反光）
            if L > 95 { continue }
            
            // 代表色本身已经含有区域占比 weight
            // 用 weight * 色度 C 当成权重：
            let w = color.weight * (C / 50.0)   // 50 是经验值，让饱和度适当地起作用
            
            warmSum += bLab * w
            weightSum += w
        
        #if DEBUG
            let hexColor = String(format: "#%02X%02X%02X",
                                Int(color.rgb.x * 255),
                                Int(color.rgb.y * 255),
                                Int(color.rgb.z * 255))
            print("     \(hexColor): L=\(String(format: "%.1f", L)), C=\(String(format: "%.1f", C)), b*=\(String(format: "%.1f", bLab)), 权重=\(String(format: "%.3f", w))")
        #endif
        }
        
        guard weightSum > 0 else { return 0 }
        
        let avgB = warmSum / weightSum      // b* 平均
        
        let clamped = max(-warmScale, min(warmScale, avgB))
        let score = clamped / warmScale     // 映射到 [-1,1]
        
        #if DEBUG
        print("     平均 b*: \(String(format: "%.2f", avgB)), 归一化: \(String(format: "%.3f", score))")
        #endif
        
        return score
    }
    
    // MARK: - 分布计算
    
    /// 计算所有照片的冷暖分布
    func calculateDistribution(photoInfos: [PhotoColorInfo]) -> WarmCoolDistribution {
        var scores: [String: WarmCoolScore] = [:]
        var allScores: [Float] = []
        
        // 收集所有得分
        for photoInfo in photoInfos {
            if let score = photoInfo.warmCoolScore {
                scores[photoInfo.assetIdentifier] = score
                allScores.append(score.overallScore)
            }
        }
        
        guard !allScores.isEmpty else {
            return WarmCoolDistribution(
                scores: [:],
                histogram: Array(repeating: 0, count: 20)
            )
        }
        
        // 计算直方图
        let bins = 20
        var histogram = Array(repeating: Float(0), count: bins)
        
        for score in allScores {
            // 将 [-1, 1] 映射到 [0, bins-1]
            let normalizedScore = (score + 1.0) / 2.0  // [0, 1]
            let binIndex = Int(normalizedScore * Float(bins - 1))
            let clampedIndex = max(0, min(bins - 1, binIndex))
            histogram[clampedIndex] += 1
        }
        
        return WarmCoolDistribution(
            scores: scores,
            histogram: histogram,
            histogramBins: bins,
            minScore: -1.0,
            maxScore: 1.0
        )
    }
    
    // MARK: - 辅助函数
    
    /// 创建空的评分结果
    private func createEmptyScore() -> WarmCoolScore {
        return WarmCoolScore(
            overallScore: 0,
            labBScore: 0,
            dominantWarmth: 0,
            hueWarmth: 0,
            warmPixelRatio: 0,
            coolPixelRatio: 0,
            neutralPixelRatio: 0,
            labBMean: 0,
            overallWarmth: 0,
            overallCoolness: 0,
            slicData: nil,
            hslData: nil
        )
    }
    
    // MARK: - RGB 转 HSL
    
    /// RGB 转 HSL
    private func rgbToHSL(r: Float, g: Float, b: Float) -> (h: Float, s: Float, l: Float) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        // Lightness
        let l = (maxC + minC) / 2.0
        
        // Saturation
        var s: Float = 0
        if delta > 0.00001 {
            s = delta / (1 - abs(2 * l - 1))
        }
        
        // Hue
        var h: Float = 0
        if delta > 0.00001 {
            if maxC == r {
                h = 60 * fmodf((g - b) / delta, 6)
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
