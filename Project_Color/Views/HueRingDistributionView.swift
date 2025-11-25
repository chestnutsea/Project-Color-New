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
        static let viewHeight: CGFloat = 200
        static let ringLineWidth: CGFloat = 1
        static let ringOpacity: Double = 0.25
        static let ringDiameterRatio: CGFloat = 0.75
        static let pointOpacity: Double = 0.45
        static let minPointDiameter: CGFloat = 10
        static let maxAdditionalDiameter: CGFloat = 36
        static let iconFontSize: CGFloat = 25
        static let iconPadding: CGFloat = 20
        #if canImport(UIKit)
        static let cardBackground = Color(UIColor.systemBackground)
        #elseif canImport(AppKit)
        static let cardBackground = Color(NSColor.windowBackgroundColor)
        #else
        static let cardBackground = Color.white
        #endif
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
                Button(action: action) {
                    Label("3D 空间", systemImage: "cube.transparent")
                        .labelStyle(.iconOnly)
                        .font(.system(size: Layout.iconFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(Layout.iconPadding)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [gradientStart, gradientEnd],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开 3D 色彩空间")
            }
        }
        .frame(height: Layout.viewHeight)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Layout.cardBackground.opacity(0.9))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        )
    }
    
    private var ringContent: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let diameter = min(size.width, size.height) * Layout.ringDiameterRatio
                let radius = diameter / 2
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                
                drawPoints(context: &context, center: center, radius: radius)
            }
        }
    }
    
    private func drawPoints(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        for point in points {
            let angle = Angle(radians: point.hue * 2 * .pi - .pi / 2)
            let x = center.x + CGFloat(cos(angle.radians)) * radius
            let y = center.y + CGFloat(sin(angle.radians)) * radius
            
            let clampedWeight = max(0.0, min(1.0, point.weight))
            let diameter = Layout.minPointDiameter + CGFloat(clampedWeight) * Layout.maxAdditionalDiameter
            let rect = CGRect(
                x: x - diameter / 2,
                y: y - diameter / 2,
                width: diameter,
                height: diameter
            )
            
            let path = Path(ellipseIn: rect)
            context.fill(
                path,
                with: .color(point.color.opacity(Layout.pointOpacity))
            )
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("暂无 Hue 分布数据")
                .font(.headline)
            Text("完成色彩分析后将展示主色环形分布。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


