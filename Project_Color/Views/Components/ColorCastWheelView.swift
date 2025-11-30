//
//  ColorCastWheelView.swift
//  Project_Color
//
//  色偏分析轮组件 - 显示高光和阴影区域的色偏分布
//

import SwiftUI

// MARK: - 色偏点模型
struct ColorCastPoint: Identifiable {
    let id = UUID()
    let hueDegrees: Double      // 0–360°（0° 在3点钟位置）
    let strength: Double        // 0–1（归一化后的强度）
    let isHighlight: Bool       // true 高光 / false 阴影
    let displayColor: Color     // 显示颜色（基于 LAB 加权平均）
}

// MARK: - 布局常量
private enum ColorCastWheelLayout {
    static let wheelSpacing: CGFloat = 16           // 两个轮之间的间距
    static let wheelHeight: CGFloat = 140           // 单个轮的高度
    static let labelSpacing: CGFloat = 8            // 轮与标签之间的间距
    static let strengthNormalizationMax: Float = 40 // strength 归一化的最大值
}

// MARK: - 点样式常量
private enum ColorCastDotStyle {
    static let minCoreSize: CGFloat = 4
    static let maxCoreSize: CGFloat = 10
    
    static let halo1SizeRatio: CGFloat = 2.0
    static let halo1Blur: CGFloat = 8
    static let halo1Opacity: Double = 0.7
    
    static let halo2SizeRatio: CGFloat = 3.0
    static let halo2Blur: CGFloat = 14
    static let halo2Opacity: Double = 0.4
    
    static let minOpacity: Double = 0.4
    static let maxOpacity: Double = 1.0
}

// MARK: - 单个极坐标散点图
private struct SingleColorCastWheel: View {
    let points: [ColorCastPoint]
    let isHighlight: Bool
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            
            ZStack {
                // 引导圆
                Circle()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.6)
                    .scaleEffect(0.66)
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                    .scaleEffect(0.33)
                
                // 散点
                ForEach(points.filter { $0.isHighlight == isHighlight }) { point in
                    let angle = point.hueDegrees * (.pi / 180)
                    let dist = CGFloat(point.strength) * radius
                    let x = cos(angle) * dist
                    let y = sin(angle) * dist
                    
                    colorCastDot(point: point)
                        .position(
                            x: geo.size.width / 2 + x,
                            y: geo.size.height / 2 + y
                        )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func colorCastDot(point: ColorCastPoint) -> some View {
        // 使用 displayColor（基于 LAB 加权平均计算的颜色）
        let baseColor = point.displayColor
        
        let strength = CGFloat(point.strength)
        let coreSize = ColorCastDotStyle.minCoreSize + (ColorCastDotStyle.maxCoreSize - ColorCastDotStyle.minCoreSize) * strength
        let halo1Size = coreSize * ColorCastDotStyle.halo1SizeRatio
        let halo2Size = coreSize * ColorCastDotStyle.halo2SizeRatio
        
        let opacityMultiplier = ColorCastDotStyle.minOpacity + (ColorCastDotStyle.maxOpacity - ColorCastDotStyle.minOpacity) * Double(strength)
        
        return ZStack {
            // 外层光晕
            Circle()
                .fill(baseColor)
                .frame(width: halo2Size, height: halo2Size)
                .blur(radius: ColorCastDotStyle.halo2Blur)
                .opacity(ColorCastDotStyle.halo2Opacity * opacityMultiplier)
            
            // 内层光晕
            Circle()
                .fill(baseColor)
                .frame(width: halo1Size, height: halo1Size)
                .blur(radius: ColorCastDotStyle.halo1Blur)
                .opacity(ColorCastDotStyle.halo1Opacity * opacityMultiplier)
            
            // 核心点
            Circle()
                .fill(baseColor)
                .frame(width: coreSize, height: coreSize)
                .opacity(opacityMultiplier)
        }
    }
}

// MARK: - 色偏状态
enum ColorCastStatus {
    case allSignificant      // 所有照片都有显著色偏
    case partialSignificant  // 部分照片有显著色偏
    case noneSignificant     // 所有照片都没有显著色偏
}

// MARK: - 色偏轮视图（双轮）
struct ColorCastWheelView: View {
    let points: [ColorCastPoint]
    let highlightStatus: ColorCastStatus
    let shadowStatus: ColorCastStatus
    
    var body: some View {
        // 双轮展示（无标题）
        HStack(spacing: ColorCastWheelLayout.wheelSpacing) {
            // 高光轮
            VStack(spacing: ColorCastWheelLayout.labelSpacing) {
                SingleColorCastWheel(points: points, isHighlight: true)
                    .frame(height: ColorCastWheelLayout.wheelHeight)
                
                Text(highlightStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            
            // 阴影轮
            VStack(spacing: ColorCastWheelLayout.labelSpacing) {
                SingleColorCastWheel(points: points, isHighlight: false)
                    .frame(height: ColorCastWheelLayout.wheelHeight)
                
                Text(shadowStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var highlightStatusText: String {
        switch highlightStatus {
        case .allSignificant:
            return "高光氛围"
        case .partialSignificant:
            return "高光氛围\n部分照片不显著"
        case .noneSignificant:
            return "高光氛围不显著"
        }
    }
    
    private var shadowStatusText: String {
        switch shadowStatus {
        case .allSignificant:
            return "阴影氛围"
        case .partialSignificant:
            return "阴影氛围\n部分照片不显著"
        case .noneSignificant:
            return "阴影氛围不显著"
        }
    }
}

// MARK: - 辅助函数：从 ColorCastResult 创建 ColorCastPoint
extension ColorCastPoint {
    /// LCH 转 RGB（用于显示颜色）
    /// L: 亮度 (0-100)
    /// C: 色度 (0-100+)
    /// H: 色相角度 (0-360°)
    private static func lchToRGB(L: Float, C: Float, H: Float) -> (r: Double, g: Double, b: Double) {
        // LCH → LAB
        let hRad = H * Float.pi / 180.0
        let a = C * cos(hRad)
        let b = C * sin(hRad)
        
        // LAB → XYZ
        let fy = (L + 16.0) / 116.0
        let fx = a / 500.0 + fy
        let fz = fy - b / 200.0
        
        let delta: Float = 6.0 / 29.0
        
        func labFInverse(_ t: Float) -> Float {
            if t > delta {
                return t * t * t
            } else {
                return 3.0 * delta * delta * (t - 4.0 / 29.0)
            }
        }
        
        // D65 白点
        let xn: Float = 0.95047
        let yn: Float = 1.00000
        let zn: Float = 1.08883
        
        let x = labFInverse(fx) * xn
        let y = labFInverse(fy) * yn
        let z = labFInverse(fz) * zn
        
        // XYZ → RGB
        var r = x * 3.2404542 + y * -1.5371385 + z * -0.4985314
        var g = x * -0.9692660 + y * 1.8760108 + z * 0.0415560
        var bVal = x * 0.0556434 + y * -0.2040259 + z * 1.0572252
        
        // 线性 RGB → sRGB
        func gammaCorrect(_ c: Float) -> Float {
            if c <= 0.0031308 {
                return 12.92 * c
            } else {
                return 1.055 * pow(c, 1.0 / 2.4) - 0.055
            }
        }
        
        r = max(0, min(1, gammaCorrect(r)))
        g = max(0, min(1, gammaCorrect(g)))
        bVal = max(0, min(1, gammaCorrect(bVal)))
        
        return (Double(r), Double(g), Double(bVal))
    }
    
    /// 从 ColorCastResult 创建高光点（如果存在）
    static func highlightPoint(from result: ColorCastResult) -> ColorCastPoint? {
        guard let hue = result.highlightHueDegrees,
              let cast = result.highlightCast else {
            return nil
        }
        
        // 归一化 strength: clamp(cast / 40, 0, 1)
        let normalizedStrength = min(1.0, max(0.0, Double(cast) / Double(ColorCastWheelLayout.strengthNormalizationMax)))
        
        // 计算显示颜色（使用 LCH）
        // L_display = 70
        // C_display = 30 + strength_norm * 40
        // H_display = hue
        let L_display: Float = 70.0
        let C_display: Float = 30.0 + Float(normalizedStrength) * 40.0
        let H_display: Float = hue
        
        let rgb = lchToRGB(L: L_display, C: C_display, H: H_display)
        let displayColor = Color(red: rgb.r, green: rgb.g, blue: rgb.b)
        
        #if DEBUG
        print("      🔆 高光点创建: cast=\(cast), hue=\(hue), strength=\(normalizedStrength), LCH=(\(L_display), \(C_display), \(H_display))")
        #endif
        
        return ColorCastPoint(
            hueDegrees: Double(hue),
            strength: normalizedStrength,
            isHighlight: true,
            displayColor: displayColor
        )
    }
    
    /// 从 ColorCastResult 创建阴影点（如果存在）
    static func shadowPoint(from result: ColorCastResult) -> ColorCastPoint? {
        guard let hue = result.shadowHueDegrees,
              let cast = result.shadowCast else {
            return nil
        }
        
        // 归一化 strength: clamp(cast / 40, 0, 1)
        let normalizedStrength = min(1.0, max(0.0, Double(cast) / Double(ColorCastWheelLayout.strengthNormalizationMax)))
        
        // 计算显示颜色（使用 LCH）
        // L_display = 70
        // C_display = 30 + strength_norm * 40
        // H_display = hue
        let L_display: Float = 70.0
        let C_display: Float = 30.0 + Float(normalizedStrength) * 40.0
        let H_display: Float = hue
        
        let rgb = lchToRGB(L: L_display, C: C_display, H: H_display)
        let displayColor = Color(red: rgb.r, green: rgb.g, blue: rgb.b)
        
        #if DEBUG
        print("      🌑 阴影点创建: cast=\(cast), hue=\(hue), strength=\(normalizedStrength), LCH=(\(L_display), \(C_display), \(H_display))")
        #endif
        
        return ColorCastPoint(
            hueDegrees: Double(hue),
            strength: normalizedStrength,
            isHighlight: false,
            displayColor: displayColor
        )
    }
}

// MARK: - 预览
struct ColorCastWheelView_Previews: PreviewProvider {
    static let demoPoints: [ColorCastPoint] = [
        // 高光点（暖色调）
        .init(hueDegrees: 30, strength: 0.8, isHighlight: true, displayColor: Color(red: 1.0, green: 0.9, blue: 0.8)),
        .init(hueDegrees: 45, strength: 0.6, isHighlight: true, displayColor: Color(red: 1.0, green: 0.95, blue: 0.85)),
        .init(hueDegrees: 200, strength: 0.5, isHighlight: true, displayColor: Color(red: 0.8, green: 0.9, blue: 1.0)),
        
        // 阴影点（冷色调）
        .init(hueDegrees: 220, strength: 0.9, isHighlight: false, displayColor: Color(red: 0.2, green: 0.25, blue: 0.35)),
        .init(hueDegrees: 240, strength: 0.7, isHighlight: false, displayColor: Color(red: 0.25, green: 0.25, blue: 0.4)),
        .init(hueDegrees: 180, strength: 0.5, isHighlight: false, displayColor: Color(red: 0.2, green: 0.3, blue: 0.3))
    ]
    
    static var previews: some View {
        VStack(spacing: 20) {
            ColorCastWheelView(
                points: demoPoints,
                highlightStatus: .allSignificant,
                shadowStatus: .partialSignificant
            )
            
            ColorCastWheelView(
                points: [],
                highlightStatus: .noneSignificant,
                shadowStatus: .noneSignificant
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}

