import SwiftUI

// ==========================================================
// MARK: - Model
// ==========================================================
struct ColorCastPoint: Identifiable {
    let id = UUID()
    let hueDegrees: Double      // 0–360°
    let strength: Double        // 0–1
    let isHighlight: Bool       // true 高光 / false 阴影
}

// ==========================================================
// MARK: - Layout Constants
// ==========================================================
struct ColorWheelLayout {
    // 布局间距
    static let outerPadding: CGFloat = 30        // 整体与屏幕边缘的距离
    static let spacingBetweenWheels: CGFloat = 30  // 两个圆形坐标轴之间的距离
}

// ==========================================================
// MARK: - Dot Style
// ==========================================================
struct ScatterDotStyle {
    // 基础尺寸参数（会根据 strength 缩放）
    static let minCoreSize: CGFloat = 3              // 最小核心尺寸
    static let maxCoreSize: CGFloat = 8              // 最大核心尺寸
    
    // 多层光晕参数（从内到外，会根据 strength 缩放）
    static let halo1SizeRatio: CGFloat = 2.0         // 相对于核心的倍数
    static let halo1Blur: CGFloat = 12
    static let halo1Opacity: Double = 0.8
    
    static let halo2SizeRatio: CGFloat = 3.0
    static let halo2Blur: CGFloat = 20
    static let halo2Opacity: Double = 0.5
    
    static let halo3SizeRatio: CGFloat = 4.0
    static let halo3Blur: CGFloat = 30
    static let halo3Opacity: Double = 0.3
    
    // 整体透明度（固定值）
    static let globalOpacity: Double = 0.5           // 所有点统一透明度

    // 高光颜色调整（更亮、更饱和）
    static let highlightBrightness: Double = 1.0      // 基础亮度
    static let highlightSaturation: Double = 1.0      // 基础饱和度
    static let highlightBrightnessBoost: Double = 0.15  // 额外提亮
    
    // 阴影颜色调整（更暗、更低饱和）
    static let shadowBrightness: Double = 0.80        // 降低亮度
    static let shadowSaturation: Double = 0.80        // 降低饱和度
}

// ==========================================================
// MARK: - Single Polar Scatter (单个圆形坐标轴)
// ==========================================================
struct SinglePolarScatter: View {
    let points: [ColorCastPoint]
    let isHighlight: Bool

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2

            ZStack {
                // --- guide circles ---
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1)
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 0.6).scaleEffect(0.66)
                Circle().stroke(Color.gray.opacity(0.15), lineWidth: 0.5).scaleEffect(0.33)

                // --- dots ---
                ForEach(points.filter { $0.isHighlight == isHighlight }) { p in
                    let angle = p.hueDegrees * (.pi / 180)
                    let dist = CGFloat(p.strength) * radius
                    let x = cos(angle) * dist
                    let y = sin(angle) * dist

                    scatterDot(point: p)
                        .position(
                            x: geo.size.width/2 + x,
                            y: geo.size.height/2 + y
                        )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // ======================================================
    // MARK: - Dot Builder
    // ======================================================
    private func scatterDot(point: ColorCastPoint) -> some View {
        let hue = point.hueDegrees / 360
        
        // 根据高光/阴影使用不同的颜色参数
        let saturation: Double
        let brightness: Double
        
        if point.isHighlight {
            saturation = ScatterDotStyle.highlightSaturation
            brightness = min(1.0, ScatterDotStyle.highlightBrightness + ScatterDotStyle.highlightBrightnessBoost)
        } else {
            saturation = ScatterDotStyle.shadowSaturation
            brightness = ScatterDotStyle.shadowBrightness
        }
        
        let baseColor = Color(hue: hue, saturation: saturation, brightness: brightness)
        
        // 根据 strength 计算尺寸（透明度固定）
        let strength = CGFloat(point.strength)  // 0-1
        let coreSize = ScatterDotStyle.minCoreSize + (ScatterDotStyle.maxCoreSize - ScatterDotStyle.minCoreSize) * strength
        let halo1Size = coreSize * ScatterDotStyle.halo1SizeRatio
        let halo2Size = coreSize * ScatterDotStyle.halo2SizeRatio
        let halo3Size = coreSize * ScatterDotStyle.halo3SizeRatio

        return ZStack {
            // 第3层光晕（最外层，最柔和）
            Circle()
                .fill(baseColor)
                .frame(width: halo3Size, height: halo3Size)
                .blur(radius: ScatterDotStyle.halo3Blur)
                .opacity(ScatterDotStyle.halo3Opacity * ScatterDotStyle.globalOpacity)
                .blendMode(.multiply)
            
            // 第2层光晕（中层）
            Circle()
                .fill(baseColor)
                .frame(width: halo2Size, height: halo2Size)
                .blur(radius: ScatterDotStyle.halo2Blur)
                .opacity(ScatterDotStyle.halo2Opacity * ScatterDotStyle.globalOpacity)
                .blendMode(.multiply)
            
            // 第1层光晕（内层，最强）
            Circle()
                .fill(baseColor)
                .frame(width: halo1Size, height: halo1Size)
                .blur(radius: ScatterDotStyle.halo1Blur)
                .opacity(ScatterDotStyle.halo1Opacity * ScatterDotStyle.globalOpacity)
                .blendMode(.multiply)

            // core（中心点）
            Circle()
                .fill(baseColor)
                .frame(width: coreSize, height: coreSize)
                .opacity(ScatterDotStyle.globalOpacity)
                .blendMode(.normal)
        }
    }
}

// ==========================================================
// MARK: - Dual Polar Scatter (双圆形坐标轴)
// ==========================================================
struct DualPolarScatterView: View {
    let points: [ColorCastPoint]

    var body: some View {
        HStack(spacing: ColorWheelLayout.spacingBetweenWheels) {
            // 左边：高光
            SinglePolarScatter(points: points, isHighlight: true)
            
            // 右边：阴影
            SinglePolarScatter(points: points, isHighlight: false)
        }
        .padding(ColorWheelLayout.outerPadding)
    }
}

// ==========================================================
// MARK: - Preview
// ==========================================================
struct DualPolarScatterView_Previews: PreviewProvider {

    static let demoPoints: [ColorCastPoint] = [
        // highlight
        .init(hueDegrees: 30, strength: 0.9, isHighlight: true),
        .init(hueDegrees: 60, strength: 0.7, isHighlight: true),
        .init(hueDegrees: 120, strength: 0.3, isHighlight: true),
        .init(hueDegrees: 200, strength: 0.5, isHighlight: true),
        .init(hueDegrees: 310, strength: 0.6, isHighlight: true),

        // shadow
        .init(hueDegrees: 220, strength: 0.85, isHighlight: false),
        .init(hueDegrees: 260, strength: 0.74, isHighlight: false),
        .init(hueDegrees: 300, strength: 0.52, isHighlight: false),
        .init(hueDegrees: 180, strength: 0.4, isHighlight: false),
        .init(hueDegrees: 340, strength: 0.25, isHighlight: false)
    ]

    static var previews: some View {
        DualPolarScatterView(points: demoPoints)
            .background(Color.white)
            .previewLayout(.sizeThatFits)
    }
}
