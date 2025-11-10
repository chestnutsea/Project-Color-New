//
//  ColorNameResolver.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 2: 基于 CSS Colors 的颜色命名（LAB 空间）
//

import Foundation
import CoreGraphics

struct NamedColor {
    let name: String
    let rgb: SIMD3<Float>
    let lab: SIMD3<Float>
}

private final class ColorNameResolverBundleToken: NSObject {}

class ColorNameResolver {
    
    private let converter = ColorSpaceConverter()
    private var palette: [NamedColor] = []
    
    init() {
        loadPalette()
    }
    
    // MARK: - 加载调色板
    
    private func loadPalette() {
        guard let url = locateColorNamesResource() else {
            print("❌ Failed to locate colornames.csv in bundle")
            palette = []
            return
        }
        
        do {
            let rawCSV = try String(contentsOf: url, encoding: .utf8)
            var results: [NamedColor] = []
            results.reserveCapacity(28_000)
            
            rawCSV.enumerateLines { line, _ in
                guard !line.isEmpty else { return }
                if line.hasPrefix("name,hex") { return } // skip header
                
                let columns = line.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
                guard columns.count >= 2 else { return }
                
                let rawName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let rawHex = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard
                    !rawName.isEmpty,
                    let rgb = self.hexToRGB(rawHex)
                else { return }
                
                let lab = self.converter.rgbToLab(rgb)
                results.append(NamedColor(name: rawName, rgb: rgb, lab: lab))
            }
            
            palette = results
            print("✅ Loaded \(palette.count) color names from colornames.csv")
        } catch {
            print("❌ Failed to load colornames.csv: \(error)")
            palette = []
        }
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
                hueModifier = "yellowish"
            } else if b < -15 && abs(a) < 10 {
                hueModifier = "bluish"
            } else if a > 15 && abs(b) < 10 {
                hueModifier = "reddish"
            } else if a < -15 && abs(b) < 10 {
                hueModifier = "greenish"
            } else if a > 10 && b > 10 {
                hueModifier = "orangish"
            } else if a < -10 && b > 10 {
                hueModifier = "lime"
            } else if a < -10 && b < -10 {
                hueModifier = "teal"
            } else if a > 10 && b < -10 {
                hueModifier = "purplish"
            }
        }
        
        // 判断亮度
        let lightnessModifier: String
        if L < 20 {
            lightnessModifier = "very dark"
        } else if L < 40 {
            lightnessModifier = "dark"
        } else if L > 80 {
            lightnessModifier = "very light"
        } else if L > 60 {
            lightnessModifier = "light"
        } else {
            lightnessModifier = ""
        }
        
        let sanitizedBase = sanitizedWords(from: baseName)
        let components = [lightnessModifier, hueModifier, sanitizedBase].filter { !$0.isEmpty }
        let combined = components.joined(separator: " ")
        let sanitized = sanitizedWords(from: combined)
        return sanitized.isEmpty ? "color" : sanitized
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
    
    // MARK: - 资源 & 解析
    
    private func locateColorNamesResource() -> URL? {
        if let url = Bundle.main.url(forResource: "colornames", withExtension: "csv") {
            return url
        }
        return Bundle(for: ColorNameResolverBundleToken.self).url(forResource: "colornames", withExtension: "csv")
    }
    
    private func hexToRGB(_ hex: String) -> SIMD3<Float>? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        
        let r = Float((value >> 16) & 0xFF) / 255.0
        let g = Float((value >> 8) & 0xFF) / 255.0
        let b = Float(value & 0xFF) / 255.0
        return SIMD3<Float>(r, g, b)
    }
    
    private func sanitizedWords(from input: String) -> String {
        guard !input.isEmpty else { return "" }
        let components = input.components(separatedBy: CharacterSet.letters.inverted)
        let words = components.filter { !$0.isEmpty }
        return words.joined(separator: " ")
    }
}

