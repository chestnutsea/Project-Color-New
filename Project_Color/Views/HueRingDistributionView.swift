//
//  HueRingDistributionView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/10.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct HueRingPoint: Identifiable {
    let id = UUID()
    let hue: Double        // 0.0 ~ 1.0
    let weight: Double     // 0.0 ~ 1.0
    let color: Color
}

struct HueRingDistributionView: View {
    private enum Layout {
        static let viewHeight: CGFloat = 170  // 与高光阴影轮高度一致（布局常量）
        static let ringLineWidth: CGFloat = 1
        static let ringOpacity: Double = 0.25
        static let ringDiameter: CGFloat = 200  // 色相环直径（布局常量）
        static let minPointDiameter: CGFloat = 10
        static let maxAdditionalDiameter: CGFloat = 36
        static let iconFontSize: CGFloat = 18  // LCh 空间入口按钮字体大小（布局常量）
        static let iconPadding: CGFloat = 12  // LCh 空间入口按钮内边距（布局常量）
        static let buttonOuterGlowSize: CGFloat = 60  // 按钮外层光晕尺寸（布局常量）
        static let buttonInnerGlowSize: CGFloat = 48  // 按钮内层光晕尺寸（布局常量）
        static let buttonCoreRadius: CGFloat = 24  // 按钮核心半径（布局常量）
        #if canImport(UIKit)
        static let cardBackground = Color(UIColor.systemBackground)
        #elseif canImport(AppKit)
        static let cardBackground = Color(NSColor.windowBackgroundColor)
        #else
        static let cardBackground = Color.white
        #endif
        
        // 发光效果参数（与 ColorCastWheelView 一致）
        static let halo1SizeRatio: CGFloat = 2.0
        static let halo1Blur: CGFloat = 8
        static let halo1Opacity: Double = 0.7
        
        static let halo2SizeRatio: CGFloat = 3.0
        static let halo2Blur: CGFloat = 14
        static let halo2Opacity: Double = 0.4
        
        static let minOpacity: Double = 0.4
        static let maxOpacity: Double = 1.0
    }
    
    var points: [HueRingPoint]
    var dominantHue: Double?
    var primaryColor: Color? = nil
    var onPresent3D: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            if points.isEmpty {
                emptyState
            } else {
                ringContent
            }
            
            if let action = onPresent3D, !points.isEmpty {
                let baseHue = dominantHue ?? 0.6
                let accentHue = (baseHue + 0.05).truncatingRemainder(dividingBy: 1.0)
                let fallbackStart = Color(hue: baseHue, saturation: 0.8, brightness: 0.9)
                let fallbackEnd = Color(hue: accentHue, saturation: 0.6, brightness: 0.85)
                let gradientStart = primaryColor ?? fallbackStart
                let gradientEnd = primaryColor?.opacity(0.75) ?? fallbackEnd
                let glowColor = primaryColor ?? fallbackStart
                
                Button(action: action) {
                    ZStack {
                        // 外层光晕
                        Circle()
                            .fill(glowColor)
                            .frame(width: Layout.buttonOuterGlowSize, height: Layout.buttonOuterGlowSize)
                            .blur(radius: 16)
                            .opacity(0.5)
                        
                        // 内层光晕
                        Circle()
                            .fill(glowColor)
                            .frame(width: Layout.buttonInnerGlowSize, height: Layout.buttonInnerGlowSize)
                            .blur(radius: 10)
                            .opacity(0.7)
                        
                        // 按钮本体
                        Label("3D 空间", systemImage: "cube.transparent")
                            .labelStyle(.iconOnly)
                            .font(.system(size: Layout.iconFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: Layout.buttonCoreRadius * 2, height: Layout.buttonCoreRadius * 2)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [gradientStart, gradientEnd],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开 3D 色彩空间")
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var ringContent: some View {
        GeometryReader { geometry in
            let diameter = Layout.ringDiameter
            let radius = diameter / 2
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            
            ZStack {
                ForEach(points) { point in
                    let angle = point.hue * 2 * .pi - .pi / 2
                    let x = CGFloat(cos(angle)) * radius
                    let y = CGFloat(sin(angle)) * radius
                    
                    glowingDot(point: point)
                        .position(x: centerX + x, y: centerY + y)
                }
            }
        }
    }
    
    private func glowingDot(point: HueRingPoint) -> some View {
        let clampedWeight = CGFloat(max(0.0, min(1.0, point.weight)))
        let coreSize = Layout.minPointDiameter + clampedWeight * Layout.maxAdditionalDiameter
        
        let opacityMultiplier = Layout.minOpacity + (Layout.maxOpacity - Layout.minOpacity) * Double(clampedWeight)
        
        // 简单的圆点，无发光效果
        return Circle()
            .fill(point.color)
            .frame(width: coreSize, height: coreSize)
            .opacity(opacityMultiplier)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(L10n.HueRing.noData.localized)
                .font(.headline)
            Text("完成色彩分析后将展示主色环形分布。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


