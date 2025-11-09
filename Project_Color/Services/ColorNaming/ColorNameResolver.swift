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
        palette = XKCDColorData.colors.map { (name, rgbTuple) in
            let rgb = SIMD3<Float>(rgbTuple.r, rgbTuple.g, rgbTuple.b)
            let lab = converter.rgbToLab(rgb)
            return NamedColor(name: name, rgb: rgb, lab: lab)
        }
        
        print("✅ Loaded \(palette.count) xkcd colors")
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
        
        // 如果色差太大（ΔE > 20），使用描述性名称
        if minDeltaE > 20.0 {
            return generateDescriptiveName(lab: lab, baseName: nearestName, deltaE: minDeltaE)
        }
        
        return nearestName
    }
    
    /// 生成描述性颜色名称（当 CSS 颜色匹配不佳时）
    private func generateDescriptiveName(lab: SIMD3<Float>, baseName: String, deltaE: Float) -> String {
        let L = lab.x  // 亮度 0-100
        let a = lab.y  // 绿-红 -128 to 127
        let b = lab.z  // 蓝-黄 -128 to 127
        
        // 判断色调倾向
        var hueModifier = ""
        if abs(a) > 10 || abs(b) > 10 {
            if b > 15 && abs(a) < 10 {
                hueModifier = "yellowish "
            } else if b < -15 && abs(a) < 10 {
                hueModifier = "bluish "
            } else if a > 15 && abs(b) < 10 {
                hueModifier = "reddish "
            } else if a < -15 && abs(b) < 10 {
                hueModifier = "greenish "
            } else if a > 10 && b > 10 {
                hueModifier = "orangish "
            } else if a < -10 && b > 10 {
                hueModifier = "lime "
            } else if a < -10 && b < -10 {
                hueModifier = "teal "
            } else if a > 10 && b < -10 {
                hueModifier = "purplish "
            }
        }
        
        // 判断亮度
        let lightnessModifier: String
        if L < 20 {
            lightnessModifier = "very dark "
        } else if L < 40 {
            lightnessModifier = "dark "
        } else if L > 80 {
            lightnessModifier = "very light "
        } else if L > 60 {
            lightnessModifier = "light "
        } else {
            lightnessModifier = ""
        }
        
        // 组合名称（英文顺序：亮度 + 色调 + 基础色）
        return "\(lightnessModifier)\(hueModifier)\(baseName)"
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

