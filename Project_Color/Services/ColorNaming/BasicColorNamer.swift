//
//  BasicColorNamer.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 1: 基础颜色命名（20个基础色，HSL映射）
//

import Foundation

class BasicColorNamer {
    
    // MARK: - 根据RGB获取颜色名称
    func getColorName(rgb: SIMD3<Float>) -> String {
        let hsl = rgbToHSL(rgb)
        return classifyColor(hsl: hsl)
    }
    
    // MARK: - RGB 转 HSL
    private func rgbToHSL(_ rgb: SIMD3<Float>) -> (h: Float, s: Float, l: Float) {
        let r = rgb.x
        let g = rgb.y
        let b = rgb.z
        
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        // Lightness
        let l = (maxC + minC) / 2.0
        
        // Saturation
        var s: Float = 0
        if delta != 0 {
            s = delta / (1 - abs(2 * l - 1))
        }
        
        // Hue
        var h: Float = 0
        if delta != 0 {
            if maxC == r {
                h = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxC == g {
                h = 60 * (((b - r) / delta) + 2)
            } else {
                h = 60 * (((r - g) / delta) + 4)
            }
        }
        
        if h < 0 {
            h += 360
        }
        
        return (h: h, s: s, l: l)
    }
    
    // MARK: - 根据HSL分类颜色
    private func classifyColor(hsl: (h: Float, s: Float, l: Float)) -> String {
        let h = hsl.h
        let s = hsl.s
        let l = hsl.l
        
        // 调试输出
        // print("HSL: h=\(h), s=\(s), l=\(l)")
        
        // 1. 极低饱和度 - 纯无彩色（黑白灰）
        if s < 0.08 {
            if l < 0.2 {
                return "黑色"
            } else if l < 0.35 {
                return "深灰"
            } else if l < 0.65 {
                return "灰色"
            } else if l < 0.85 {
                return "浅灰"
            } else {
                return "白色"
            }
        }
        
        // 2. 低饱和度（0.08-0.20）- 淡彩色
        if s < 0.20 {
            // 根据色相判断倾向
            if h >= 30 && h < 70 {
                return l > 0.6 ? "米白色" : "土黄色"
            } else if h >= 0 && h < 30 || h >= 330 {
                return l > 0.6 ? "粉白色" : "褐红色"
            } else if h >= 70 && h < 150 {
                return l > 0.6 ? "淡绿色" : "橄榄绿"
            } else if h >= 150 && h < 270 {
                return l > 0.6 ? "淡蓝色" : "灰蓝色"
            } else {
                return l > 0.6 ? "淡紫色" : "灰紫色"
            }
        }
        
        // 3. 有彩色（饱和度 >= 0.20）- 根据色相分类
        let baseColor: String
        if h >= 0 && h < 20 {
            baseColor = "红色"
        } else if h >= 20 && h < 45 {
            baseColor = "橙色"
        } else if h >= 45 && h < 70 {
            baseColor = "黄色"
        } else if h >= 70 && h < 90 {
            baseColor = "黄绿色"
        } else if h >= 90 && h < 150 {
            baseColor = "绿色"
        } else if h >= 150 && h < 180 {
            baseColor = "青绿色"
        } else if h >= 180 && h < 210 {
            baseColor = "青色"
        } else if h >= 210 && h < 250 {
            baseColor = "蓝色"
        } else if h >= 250 && h < 280 {
            baseColor = "蓝紫色"
        } else if h >= 280 && h < 320 {
            baseColor = "紫色"
        } else if h >= 320 && h < 340 {
            baseColor = "紫红色"
        } else {
            baseColor = "粉红色"
        }
        
        // 添加亮度修饰
        if l < 0.25 {
            return "深\(baseColor)"
        } else if l > 0.75 {
            return "浅\(baseColor)"
        } else if s > 0.6 {
            return "鲜\(baseColor)"
        } else {
            return baseColor
        }
    }
}

