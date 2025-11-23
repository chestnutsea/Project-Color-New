import SwiftUI

struct ParticleFlowerView: View {
    @State private var rotation: Angle = .degrees(0)

    private let skyBlue     = Color(red: 0.53, green: 0.81, blue: 0.98) // 天蓝
    private let lightYellow = Color(red: 1.00, green: 0.95, blue: 0.70) // 淡黄
    private let pinkPurple  = Color(red: 0.93, green: 0.70, blue: 0.93) // 粉紫

    var body: some View {
        ZStack {
            // 背景稍微有点柔和渐变
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.95),
                    Color(red: 0.05, green: 0.06, blue: 0.12)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2,
                                     y: size.height / 2)
                let maxRadius = min(size.width, size.height) * 0.40
                let particleCount = 1800

                for i in 0..<particleCount {
                    let t = Double(i) / Double(particleCount)    // 0~1
                    let angle = t * Double.pi * 10.0             // 花瓣圈数
                    let rose = cos(5 * angle)                    // 玫瑰线参数（决定花瓣形状）

                    // 基础半径 + 一点「粒子抖动」
                    let baseRadius = maxRadius * abs(rose) * (0.4 + 0.6 * t)
                    let jitter = maxRadius * 0.02 * sin(Double(i) * 12.9898)
                    let radius = baseRadius + jitter

                    let x = center.x + CGFloat(cos(angle) * radius)
                    let y = center.y + CGFloat(sin(angle) * radius)

                    // 粒子大小随半径略变化
                    let sizeFactor = 0.6 + 0.4 * CGFloat(abs(rose))
                    let particleSize = maxRadius * 0.012 * sizeFactor

                    var particlePath = Path()
                    particlePath.addEllipse(
                        in: CGRect(
                            x: x - particleSize / 2,
                            y: y - particleSize / 2,
                            width: particleSize,
                            height: particleSize
                        )
                    )

                    // 根据 t 决定颜色分布：中心偏天蓝，中圈淡黄，外围粉紫
                    let color: Color
                    switch t {
                    case 0..<0.33:
                        color = skyBlue
                    case 0.33..<0.66:
                        color = lightYellow
                    default:
                        color = pinkPurple
                    }

                    let opacity = 0.35 + 0.65 * Double(0.5 + 0.5 * rose * rose)

                    context.fill(
                        particlePath,
                        with: .color(color.opacity(opacity))
                    )
                }
            }
            .rotationEffect(rotation)          // 整体缓慢旋转
            .blur(radius: 1.2)                 // 稍微糊一点，看起来更像光点
            .drawingGroup()                    // 提升渲染质量
            .frame(width: 350, height: 350)
        }
        .onAppear {
            withAnimation(.linear(duration: 40)
                .repeatForever(autoreverses: false)) {
                rotation = .degrees(360)
            }
        }
    }
}

struct ContentView1: View {
    var body: some View {
        ParticleFlowerView()
    }
}

#Preview {
    ContentView1()
}
