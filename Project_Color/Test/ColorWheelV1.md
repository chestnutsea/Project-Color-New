//
//  ColorWheelV1.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/22.
//

import SwiftUI

// ==========================================================
// MARK: - Dot Layout Config
// ==========================================================
struct DotConfig {
    static let dotSize: CGFloat = 5
    static let glowSize: CGFloat = 20
    static let glowBlur: CGFloat = 6
    static let glowOpacity: Double = 0.45
}

// ==========================================================
// MARK: - Highlight Wheel Bloom Config
// ==========================================================
struct HighlightWheelBloomConfig {
    static let bigBlur: CGFloat = 220
    static let bigOpacity: Double = 0.32
    static let bigScale: CGFloat = 2.2

    static let radialBlur: CGFloat = 130
    static let radialOpacity: Double = 0.55
    static let radialScale: CGFloat = 1.55
}

// ==========================================================
// MARK: - Highlight Wheel Color Adjust
// ==========================================================
struct HighlightWheelColorAdjust {
    static let saturation: Double = 1
    static let brightness: Double = 0.5
    static let contrast: Double = 1

    static let softlightOpacity: Double = 0.28
}

// ==========================================================
// MARK: - Model
// ==========================================================
struct ColorCastPoint: Identifiable {
    let id = UUID()
    let hueDegrees: Double
    let strength: Double
}

// ==========================================================
// MARK: - Hue Wheel
// ==========================================================
struct HueWheel: View {
    let points: [ColorCastPoint]
    let isHighlightWheel: Bool
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            
            ZStack {
                
                // ===================================================
                // 1. Base Color Wheel with Color Adjustments
                // ===================================================
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: stride(from: 0, to: 360, by: 1).map {
                                Color(hue: Double($0)/360.0, saturation: 1, brightness: 1)
                            }),
                            center: .center
                        )
                    )
                    .if(isHighlightWheel) { view in
                        view
                            .saturation(HighlightWheelColorAdjust.saturation)
                            .brightness(HighlightWheelColorAdjust.brightness)
                            .contrast(HighlightWheelColorAdjust.contrast)
                    }
                
                // 黑遮罩
                Circle()
                    .fill(Color.black.opacity(0.4))
                
                // ===================================================
                // 2. Global Bleach Bloom (only for highlight wheel)
                // ===================================================
                if isHighlightWheel {
                    ZStack {
                        
                        // Outer Huge diffuse bloom
                        Circle()
                            .fill(Color.white)
                            .scaleEffect(HighlightWheelBloomConfig.bigScale)
                            .blur(radius: HighlightWheelBloomConfig.bigBlur, opaque: false)
                            .opacity(HighlightWheelBloomConfig.bigOpacity)
                            .blendMode(.screen)
                        
                        // Inner radial bloom
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(1.0),
                                        Color.white.opacity(0.0)
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: radius * 0.9
                                )
                            )
                            .scaleEffect(HighlightWheelBloomConfig.radialScale)
                            .blur(radius: HighlightWheelBloomConfig.radialBlur, opaque: false)
                            .opacity(HighlightWheelBloomConfig.radialOpacity)
                            .blendMode(.screen)
                        
                        // Softlight overlay (柔光层)
                        Circle()
                            .fill(Color.white)
                            .opacity(HighlightWheelColorAdjust.softlightOpacity)
                            .blendMode(.softLight)
                    }
                    .compositingGroup()
                }
                
                // ===================================================
                // 3. Tiny Colored Dots
                // ===================================================
                ForEach(points) { point in
                    let angleRad = point.hueDegrees * .pi / 180
                    let dist = point.strength * radius
                    let x = cos(angleRad) * dist
                    let y = sin(angleRad) * dist
                    
                    let color = Color(
                        hue: point.hueDegrees / 360,
                        saturation: 1,
                        brightness: 1
                    )
                    
                    ZStack {
                        Circle()
                            .fill(color)
                            .frame(width: DotConfig.dotSize, height: DotConfig.dotSize)
                        
                        Circle()
                            .fill(color)
                            .frame(width: DotConfig.glowSize, height: DotConfig.glowSize)
                            .blur(radius: DotConfig.glowBlur, opaque: false)
                            .opacity(DotConfig.glowOpacity)
                    }
                    .position(x: geo.size.width/2 + x, y: geo.size.height/2 + y)
                }
            }
        }
    }
}

// ==========================================================
// MARK: - Two Wheels Side by Side
// ==========================================================
struct DualHueWheelView: View {
    let highlightPoints: [ColorCastPoint]
    let shadowPoints: [ColorCastPoint]
    
    var body: some View {
        HStack(spacing: 20) {
            HueWheel(points: highlightPoints, isHighlightWheel: true)
            HueWheel(points: shadowPoints, isHighlightWheel: false)
        }
        .padding()
    }
}

// ==========================================================
// MARK: - Preview
// ==========================================================
struct DualHueWheelView_Previews: PreviewProvider {
    static let demoHighlight = [
        ColorCastPoint(hueDegrees: 30, strength: 0.8),
        ColorCastPoint(hueDegrees: 350, strength: 0.5),
        ColorCastPoint(hueDegrees: 60, strength: 0.6),
        ColorCastPoint(hueDegrees: 120, strength: 0.4),
        ColorCastPoint(hueDegrees: 200, strength: 0.3)
    ]
    
    static let demoShadow = [
        ColorCastPoint(hueDegrees: 220, strength: 0.9),
        ColorCastPoint(hueDegrees: 260, strength: 0.7),
        ColorCastPoint(hueDegrees: 300, strength: 0.6),
        ColorCastPoint(hueDegrees: 180, strength: 0.5),
        ColorCastPoint(hueDegrees: 330, strength: 0.3)
    ]
    
    static var previews: some View {
        DualHueWheelView(
            highlightPoints: demoHighlight,
            shadowPoints: demoShadow
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}


// ------------------------------------------------------------
// MARK: - View Modifier Helper (.if condition)
// ------------------------------------------------------------
extension View {
    @ViewBuilder func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition { transform(self) }
        else { self }
    }
}
