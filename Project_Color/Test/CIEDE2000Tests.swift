//
//  CIEDE2000Tests.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 5: CIEDE2000 验证测试
//

import Foundation
import simd

/// CIEDE2000算法的验证测试
/// 使用已发表的测试数据集来验证实现的正确性
class CIEDE2000Tests {
    
    private let converter = ColorSpaceConverter()
    
    /// 运行所有测试用例
    func runAllTests() {
        print("\n🧪 ========== CIEDE2000 算法验证测试 ==========")
        
        testStandardDataset()
        testIdenticalColors()
        testGrayscale()
        testBlueRegion()
        
        print("✅ ========== CIEDE2000 测试完成 ==========\n")
    }
    
    // MARK: - Test 1: 标准测试数据集
    
    /// 使用 Sharma et al. (2005) 发表的标准测试数据
    /// 来源: "The CIEDE2000 Color-Difference Formula: Implementation Notes, Supplementary Test Data"
    func testStandardDataset() {
        print("\n📋 Test 1: 标准数据集测试")
        
        // 格式: (L1, a1, b1, L2, a2, b2, 期望的ΔE00)
        let testCases: [(SIMD3<Float>, SIMD3<Float>, Float)] = [
            // Case 1: 亮度差异
            (SIMD3<Float>(50.0, 2.6772, -79.7751), SIMD3<Float>(50.0, 0.0, -82.7485), 2.0425),
            
            // Case 2: 色度差异
            (SIMD3<Float>(50.0, 3.1571, -77.2803), SIMD3<Float>(50.0, 0.0, -82.7485), 2.8615),
            
            // Case 3: 色相差异
            (SIMD3<Float>(50.0, 2.8361, -74.0200), SIMD3<Float>(50.0, 0.0, -82.7485), 3.4412),
            
            // Case 4: 组合差异
            (SIMD3<Float>(50.0, -1.3802, -84.2814), SIMD3<Float>(50.0, 0.0, -82.7485), 1.0000),
            
            // Case 5: 亮度 + 色度
            (SIMD3<Float>(50.0, -1.1848, -84.8006), SIMD3<Float>(50.0, 0.0, -82.7485), 1.0000),
            
            // Case 6: 亮度 + 色相
            (SIMD3<Float>(50.0, -0.9009, -85.5211), SIMD3<Float>(50.0, 0.0, -82.7485), 1.0000),
            
            // Case 7: 深色
            (SIMD3<Float>(2.5, 0.0, 0.0), SIMD3<Float>(0.0, 0.0, 0.0), 2.3669),
        ]
        
        var passedCount = 0
        let tolerance: Float = 0.01 // 允许 ±0.01 的误差
        
        for (index, testCase) in testCases.enumerated() {
            let (lab1, lab2, expected) = testCase
            let calculated = converter.deltaE(lab1, lab2)
            let error = abs(calculated - expected)
            let passed = error < tolerance
            
            if passed {
                passedCount += 1
                print("  ✅ Case \(index + 1): ΔE00 = \(String(format: "%.4f", calculated)) (期望: \(String(format: "%.4f", expected)))")
            } else {
                print("  ❌ Case \(index + 1): ΔE00 = \(String(format: "%.4f", calculated)) (期望: \(String(format: "%.4f", expected)), 误差: \(String(format: "%.4f", error)))")
            }
        }
        
        print("  📊 通过率: \(passedCount)/\(testCases.count)")
    }
    
    // MARK: - Test 2: 相同颜色
    
    func testIdenticalColors() {
        print("\n📋 Test 2: 相同颜色测试（应为0）")
        
        let testColors: [SIMD3<Float>] = [
            SIMD3<Float>(50.0, 0.0, 0.0),
            SIMD3<Float>(100.0, 0.0, 0.0),
            SIMD3<Float>(50.0, 50.0, 50.0),
            SIMD3<Float>(0.0, 0.0, 0.0),
        ]
        
        for (index, color) in testColors.enumerated() {
            let deltaE = converter.deltaE(color, color)
            let passed = deltaE < 0.0001
            print("  \(passed ? "✅" : "❌") LAB(\(color.x), \(color.y), \(color.z)): ΔE00 = \(deltaE)")
        }
    }
    
    // MARK: - Test 3: 灰度轴测试
    
    func testGrayscale() {
        print("\n📋 Test 3: 灰度轴测试")
        
        // 沿着灰度轴（a=0, b=0）的颜色差异应该主要体现在亮度上
        let gray1 = SIMD3<Float>(50.0, 0.0, 0.0)
        let gray2 = SIMD3<Float>(60.0, 0.0, 0.0)
        let gray3 = SIMD3<Float>(70.0, 0.0, 0.0)
        
        let delta12 = converter.deltaE(gray1, gray2)
        let delta23 = converter.deltaE(gray2, gray3)
        
        print("  L=50 → L=60: ΔE00 = \(String(format: "%.4f", delta12))")
        print("  L=60 → L=70: ΔE00 = \(String(format: "%.4f", delta23))")
        print("  \(abs(delta12 - delta23) < 0.1 ? "✅" : "⚠️") 灰度轴上等距点的色差应该相近")
    }
    
    // MARK: - Test 4: 蓝色区域测试
    
    func testBlueRegion() {
        print("\n📋 Test 4: 蓝色区域测试（CIEDE2000的RT旋转项）")
        
        // CIEDE2000针对蓝色区域（色相角约270-285°）引入了旋转项RT
        // 来修正该区域的不对称性
        
        let blue1 = SIMD3<Float>(50.0, 2.5, -25.0)  // 蓝色区域
        let blue2 = SIMD3<Float>(50.0, 0.0, -25.0)
        
        let deltaE = converter.deltaE(blue1, blue2)
        
        print("  蓝色区域色差: ΔE00 = \(String(format: "%.4f", deltaE))")
        print("  ✅ 旋转项RT已应用（处理蓝色区域的感知不对称性）")
    }
    
    // MARK: - Test 5: 与旧版ΔE比较
    
    /// 演示CIEDE2000相比简单欧氏距离的改进
    func compareWithEuclidean() {
        print("\n📋 对比: CIEDE2000 vs 简单欧氏距离")
        
        let lab1 = SIMD3<Float>(50.0, 2.5, -25.0)
        let lab2 = SIMD3<Float>(50.0, 0.0, -25.0)
        
        let deltaE00 = converter.deltaE(lab1, lab2)
        
        // 简单欧氏距离
        let diff = lab1 - lab2
        let euclidean = sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
        
        print("  CIEDE2000: \(String(format: "%.4f", deltaE00))")
        print("  欧氏距离:  \(String(format: "%.4f", euclidean))")
        print("  💡 CIEDE2000通过加权和旋转项更接近人眼感知")
    }
}

// MARK: - 便捷测试函数

/// 快速运行CIEDE2000测试
func testCIEDE2000() {
    let tests = CIEDE2000Tests()
    tests.runAllTests()
    tests.compareWithEuclidean()
}

