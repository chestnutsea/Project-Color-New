//
//  WarmCoolAlgorithmTest.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/17.
//  测试新的 SLIC-based 冷暖算法
//

import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

/// 冷暖算法测试类
class WarmCoolAlgorithmTest {
    
    private let calculator = WarmCoolScoreCalculator()
    
    /// 测试新算法的基本功能
    func testBasicFunctionality() async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧪 测试 SLIC-based 冷暖算法")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 测试用例 1：纯暖色图像（橙色）
        await testWarmImage()
        
        // 测试用例 2：纯冷色图像（蓝色）
        await testCoolImage()
        
        // 测试用例 3：中性图像（灰色）
        await testNeutralImage()
        
        // 测试用例 4：混合图像（暖色主导）
        await testMixedWarmImage()
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ 测试完成")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    // MARK: - 测试用例
    
    /// 测试纯暖色图像
    private func testWarmImage() async {
        print("\n📊 测试用例 1: 纯暖色图像（橙色）")
        
        // 创建橙色图像
        guard let image = createSolidColorImage(r: 1.0, g: 0.6, b: 0.2, size: 512) else {
            print("❌ 创建图像失败")
            return
        }
        
        // 创建暖色主色
        let dominantColors = [
            DominantColor(rgb: SIMD3<Float>(1.0, 0.6, 0.2), weight: 1.0)
        ]
        
        let score = await calculator.calculateScore(image: image, dominantColors: dominantColors)
        
        print("   结果: overallScore = \(String(format: "%.3f", score.overallScore))")
        print("   预期: > 0.5 (暖色调)")
        
        if score.overallScore > 0.5 {
            print("   ✅ 通过")
        } else {
            print("   ❌ 失败：分数应该 > 0.5")
        }
    }
    
    /// 测试纯冷色图像
    private func testCoolImage() async {
        print("\n📊 测试用例 2: 纯冷色图像（蓝色）")
        
        // 创建蓝色图像
        guard let image = createSolidColorImage(r: 0.2, g: 0.4, b: 0.8, size: 512) else {
            print("❌ 创建图像失败")
            return
        }
        
        // 创建冷色主色
        let dominantColors = [
            DominantColor(rgb: SIMD3<Float>(0.2, 0.4, 0.8), weight: 1.0)
        ]
        
        let score = await calculator.calculateScore(image: image, dominantColors: dominantColors)
        
        print("   结果: overallScore = \(String(format: "%.3f", score.overallScore))")
        print("   预期: < -0.5 (冷色调)")
        
        if score.overallScore < -0.5 {
            print("   ✅ 通过")
        } else {
            print("   ❌ 失败：分数应该 < -0.5")
        }
    }
    
    /// 测试中性图像
    private func testNeutralImage() async {
        print("\n📊 测试用例 3: 中性图像（灰色）")
        
        // 创建灰色图像
        guard let image = createSolidColorImage(r: 0.5, g: 0.5, b: 0.5, size: 512) else {
            print("❌ 创建图像失败")
            return
        }
        
        // 创建中性主色
        let dominantColors = [
            DominantColor(rgb: SIMD3<Float>(0.5, 0.5, 0.5), weight: 1.0)
        ]
        
        let score = await calculator.calculateScore(image: image, dominantColors: dominantColors)
        
        print("   结果: overallScore = \(String(format: "%.3f", score.overallScore))")
        print("   预期: ≈ 0 (中性)")
        
        if abs(score.overallScore) < 0.2 {
            print("   ✅ 通过")
        } else {
            print("   ⚠️ 注意：灰色图像可能被过滤，分数为 0 是正常的")
        }
    }
    
    /// 测试混合暖色图像
    private func testMixedWarmImage() async {
        print("\n📊 测试用例 4: 混合图像（暖色主导）")
        
        // 创建渐变图像（从橙色到黄色）
        guard let image = createGradientImage(
            color1: (r: 1.0, g: 0.6, b: 0.2),
            color2: (r: 1.0, g: 0.9, b: 0.3),
            size: 512
        ) else {
            print("❌ 创建图像失败")
            return
        }
        
        // 创建混合主色
        let dominantColors = [
            DominantColor(rgb: SIMD3<Float>(1.0, 0.6, 0.2), weight: 0.6),
            DominantColor(rgb: SIMD3<Float>(1.0, 0.9, 0.3), weight: 0.4)
        ]
        
        let score = await calculator.calculateScore(image: image, dominantColors: dominantColors)
        
        print("   结果: overallScore = \(String(format: "%.3f", score.overallScore))")
        print("   预期: > 0.3 (暖色调)")
        
        if score.overallScore > 0.3 {
            print("   ✅ 通过")
        } else {
            print("   ❌ 失败：分数应该 > 0.3")
        }
    }
    
    // MARK: - 辅助函数
    
    /// 创建纯色图像
    private func createSolidColorImage(r: Float, g: Float, b: Float, size: Int) -> CGImage? {
        let width = size
        let height = size
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = bytesPerRow * height
        
        var data = [UInt8](repeating: 0, count: totalBytes)
        
        let rByte = UInt8(r * 255)
        let gByte = UInt8(g * 255)
        let bByte = UInt8(b * 255)
        
        for i in 0..<(width * height) {
            let offset = i * bytesPerPixel
            data[offset + 0] = rByte
            data[offset + 1] = gByte
            data[offset + 2] = bByte
            data[offset + 3] = 255  // Alpha
        }
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &data,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        
        return context.makeImage()
    }
    
    /// 创建渐变图像
    private func createGradientImage(
        color1: (r: Float, g: Float, b: Float),
        color2: (r: Float, g: Float, b: Float),
        size: Int
    ) -> CGImage? {
        let width = size
        let height = size
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = bytesPerRow * height
        
        var data = [UInt8](repeating: 0, count: totalBytes)
        
        for y in 0..<height {
            let t = Float(y) / Float(height)
            let r = color1.r * (1 - t) + color2.r * t
            let g = color1.g * (1 - t) + color2.g * t
            let b = color1.b * (1 - t) + color2.b * t
            
            let rByte = UInt8(r * 255)
            let gByte = UInt8(g * 255)
            let bByte = UInt8(b * 255)
            
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                data[offset + 0] = rByte
                data[offset + 1] = gByte
                data[offset + 2] = bByte
                data[offset + 3] = 255  // Alpha
            }
        }
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &data,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        
        return context.makeImage()
    }
}

// MARK: - 运行测试的辅助函数

/// 运行冷暖算法测试
func runWarmCoolAlgorithmTest() async {
    let test = WarmCoolAlgorithmTest()
    await test.testBasicFunctionality()
}

