//
//  ColorNameResolver.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 2: 基于 CSS Colors 的颜色命名（LAB 空间）
//

import Foundation

struct NamedColor {
    let name: String
    let rgb: SIMD3<Float>
    let lab: SIMD3<Float>
}

class ColorNameResolver {
    
    private let converter = ColorSpaceConverter()
    private var palette: [NamedColor] = []
    
    init() {
        loadPalette()
    }
    
    // MARK: - 加载调色板
    
    private func loadPalette() {
        palette = CSSColorData.colors.map { (name, rgbTuple) in
            let rgb = SIMD3<Float>(rgbTuple.r, rgbTuple.g, rgbTuple.b)
            let lab = converter.rgbToLab(rgb)
            return NamedColor(name: name, rgb: rgb, lab: lab)
        }
        
        print("✅ Loaded \(palette.count) CSS colors")
    }
    
    // MARK: - 颜色命名（LAB 空间最近邻）
    
    /// 根据 RGB 值获取最接近的 CSS 颜色名称
    func getColorName(rgb: SIMD3<Float>) -> String {
        let lab = converter.rgbToLab(rgb)
        return getColorName(lab: lab)
    }
    
    /// 根据 LAB 值获取最接近的 CSS 颜色名称
    func getColorName(lab: SIMD3<Float>) -> String {
        var minDeltaE = Float.greatestFiniteMagnitude
        var nearestName = "Unknown"
        
        for namedColor in palette {
            let deltaE = converter.deltaE(lab, namedColor.lab)
            if deltaE < minDeltaE {
                minDeltaE = deltaE
                nearestName = namedColor.name
            }
        }
        
        return nearestName
    }
    
    /// 获取最接近的颜色名称及其色差值
    func getColorNameWithDistance(rgb: SIMD3<Float>) -> (name: String, deltaE: Float) {
        let lab = converter.rgbToLab(rgb)
        
        var minDeltaE = Float.greatestFiniteMagnitude
        var nearestName = "Unknown"
        
        for namedColor in palette {
            let deltaE = converter.deltaE(lab, namedColor.lab)
            if deltaE < minDeltaE {
                minDeltaE = deltaE
                nearestName = namedColor.name
            }
        }
        
        return (name: nearestName, deltaE: minDeltaE)
    }
    
    // MARK: - 辅助方法
    
    /// 获取所有颜色名称（用于测试）
    func getAllColorNames() -> [String] {
        return palette.map { $0.name }
    }
    
    /// 根据名称查找颜色
    func findColor(byName name: String) -> NamedColor? {
        return palette.first { $0.name.lowercased() == name.lowercased() }
    }
}

