//
//  WarmCoolScoreTest.swift
//  Project_Color
//
//  测试冷暖值映射问题
//

import Foundation
import CoreGraphics

/// 测试工具：分析 Lab b* 值的实际分布
class WarmCoolScoreTest {
    
    /// 分析一组照片的 b* 值分布
    static func analyzeBStarDistribution(images: [CGImage]) {
        var allBValues: [Float] = []
        
        for image in images {
            if let bValues = extractBStarValues(from: image) {
                allBValues.append(contentsOf: bValues)
            }
        }
        
        guard !allBValues.isEmpty else {
            print("❌ 没有提取到 b* 值")
            return
        }
        
        // 统计分析
        let sorted = allBValues.sorted()
        let count = allBValues.count
        
        let minValue = sorted.first ?? 0
        let maxValue = sorted.last ?? 0
        let mean = allBValues.reduce(0, +) / Float(count)
        let median = sorted[count / 2]
        
        // 百分位数
        let p5 = sorted[Int(Float(count) * 0.05)]
        let p25 = sorted[Int(Float(count) * 0.25)]
        let p75 = sorted[Int(Float(count) * 0.75)]
        let p95 = sorted[Int(Float(count) * 0.95)]
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 Lab b* 值分布统计")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("总像素数: \(count)")
        print("")
        print("基本统计:")
        print("  最小值: \(String(format: "%.2f", minValue))")
        print("  最大值: \(String(format: "%.2f", maxValue))")
        print("  平均值: \(String(format: "%.2f", mean))")
        print("  中位数: \(String(format: "%.2f", median))")
        print("")
        print("百分位数:")
        print("  5%:  \(String(format: "%.2f", p5))")
        print("  25%: \(String(format: "%.2f", p25))")
        print("  75%: \(String(format: "%.2f", p75))")
        print("  95%: \(String(format: "%.2f", p95))")
        print("")
        print("建议的缩放因子:")
        print("  基于 95% 范围: \(String(format: "%.1f", max(abs(p5), abs(p95))))")
        print("  基于最大范围: \(String(format: "%.1f", max(abs(minValue), abs(maxValue))))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 测试不同缩放因子的效果
        print("")
        print("不同缩放因子下的归一化效果:")
        testScalingFactors(mean: mean, scales: [30, 40, 50, 60, 80, 100])
    }
    
    /// 测试不同缩放因子
    private static func testScalingFactors(mean: Float, scales: [Float]) {
        for scale in scales {
            let normalized = mean / scale
            let clampedNormalized = max(-1, min(1, normalized))
            print("  scale=\(String(format: "%.0f", scale)): mean=\(String(format: "%.2f", mean)) → normalized=\(String(format: "%.3f", clampedNormalized))")
        }
    }
    
    /// 从图像中提取所有像素的 b* 值
    private static func extractBStarValues(from cgImage: CGImage) -> [Float]? {
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
        
        var bValues: [Float] = []
        bValues.reserveCapacity(width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * bytesPerRow + x * bytesPerPixel
                let r = Float(rawData[byteIndex + 0]) / 255.0
                let g = Float(rawData[byteIndex + 1]) / 255.0
                let b = Float(rawData[byteIndex + 2]) / 255.0
                
                let (_, _, bLab) = sRGBToLab(r: r, g: g, b: b)
                bValues.append(bLab)
            }
        }
        
        return bValues
    }
    
    /// sRGB 转 Lab
    private static func sRGBToLab(r: Float, g: Float, b: Float) -> (Float, Float, Float) {
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
}

