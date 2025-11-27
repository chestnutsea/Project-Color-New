import SwiftUI
import Combine

// MARK: - Apple 风运动参数（真实“漂流”而不是抖动）

private enum AppleMotion {
    static let damping: CGFloat = 0.998        // ✅ 非常弱的阻尼 → 可以一直漂
    static let driftStrength: CGFloat = 0.002  // ✅ 极小扰动 → 防止死直线
    static let maxSpeed: CGFloat = 0.8         // ✅ 真实移动速度
    static let boundarySoftness: CGFloat = 0.85 // ✅ 软回弹（不弹飞）
}

// MARK: - 示例能量球模型

struct DemoColorCircle: Identifiable {
    let id = UUID()
    let color: Color
    var position: CGPoint
    let radius: CGFloat
    var velocity: CGPoint
}

// MARK: - 主视图

struct ColorEmergeSpaceDemoView: View {
    
    @State private var circles: [DemoColorCircle] = []
    @State private var screenSize: CGSize = .zero
    @State private var isAnimating = false
    
    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ✅ Apple 锁屏级空间背景（白黑自适应）
                appleSpaceBackground
                
                // ✅ 漂浮能量球（真实移动）
                ZStack {
                    ForEach(circles) { circle in
                        glowingCircle(circle: circle)
                            .position(circle.position)
                    }
                }
            }
            .onAppear {
                screenSize = geometry.size
                isAnimating = true
                injectDemoCircles(size: geometry.size)
            }
            .onReceive(timer) { _ in
                guard isAnimating else { return }
                updateAppleStyleMotion()
            }
        }
    }
}

// MARK: - ✅ 注入示例圆（带真实初速度）

extension ColorEmergeSpaceDemoView {
    
    private func injectDemoCircles(size: CGSize) {
        circles = [
            makeDemoCircle(color: .blue,   radius: 30, size: size),
            makeDemoCircle(color: .purple, radius: 24, size: size),
            makeDemoCircle(color: .orange, radius: 36, size: size),
            makeDemoCircle(color: .green,  radius: 28, size: size),
            makeDemoCircle(color: .pink,   radius: 22, size: size)
        ]
    }
    
    private func makeDemoCircle(color: Color, radius: CGFloat, size: CGSize) -> DemoColorCircle {
        let x = CGFloat.random(in: radius...(size.width - radius))
        let y = CGFloat.random(in: radius...(size.height - radius))
        
        let angle = CGFloat.random(in: 0...(2 * .pi))
        
        // ✅ 关键：给一个“真实会移动”的初始速度
        let speed = CGFloat.random(in: 0.35...0.6)
        
        return DemoColorCircle(
            color: color,
            position: CGPoint(x: x, y: y),
            radius: radius,
            velocity: CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed
            )
        )
    }
}

// MARK: - ✅ Apple 风真实漂流运动（不是原地晃）

extension ColorEmergeSpaceDemoView {
    
    private func updateAppleStyleMotion() {
        for i in 0..<circles.count {
            var c = circles[i]
            
            // ✅ 极弱阻尼（保证长期移动）
            c.velocity.x *= AppleMotion.damping
            c.velocity.y *= AppleMotion.damping
            
            // ✅ 极小随机扰动（只为防止死直线）
            c.velocity.x += CGFloat.random(in: -AppleMotion.driftStrength...AppleMotion.driftStrength)
            c.velocity.y += CGFloat.random(in: -AppleMotion.driftStrength...AppleMotion.driftStrength)
            
            // ✅ 限速（防止失控）
            c.velocity.x = max(min(c.velocity.x, AppleMotion.maxSpeed), -AppleMotion.maxSpeed)
            c.velocity.y = max(min(c.velocity.y, AppleMotion.maxSpeed), -AppleMotion.maxSpeed)
            
            // ✅ 真实“位移”
            c.position.x += c.velocity.x
            c.position.y += c.velocity.y
            
            // ✅ 软边界回弹（像气泡撞到空气墙）
            let pad = c.radius + 16
            
            if c.position.x < pad {
                c.position.x = pad
                c.velocity.x = abs(c.velocity.x) * AppleMotion.boundarySoftness
            }
            
            if c.position.x > screenSize.width - pad {
                c.position.x = screenSize.width - pad
                c.velocity.x = -abs(c.velocity.x) * AppleMotion.boundarySoftness
            }
            
            if c.position.y < pad {
                c.position.y = pad
                c.velocity.y = abs(c.velocity.y) * AppleMotion.boundarySoftness
            }
            
            if c.position.y > screenSize.height - pad {
                c.position.y = screenSize.height - pad
                c.velocity.y = -abs(c.velocity.y) * AppleMotion.boundarySoftness
            }
            
            circles[i] = c
        }
    }
}

// MARK: - ✅ Apple 风发光能量球（无呼吸、纯漂流）

extension ColorEmergeSpaceDemoView {
    
    private func glowingCircle(circle: DemoColorCircle) -> some View {
        let r = circle.radius
        
        return ZStack {
            // ✅ 空间环境光
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            circle.color.opacity(0.35),
                            circle.color.opacity(0.15),
                            .clear
                        ]),
                        center: .center,
                        startRadius: r * 0.3,
                        endRadius: r * 2.2
                    )
                )
                .frame(
                    width: r * 4.4,
                    height: r * 4.4
                )
                .blendMode(.screen)
            
            // ✅ 体积柔光
            Circle()
                .fill(circle.color)
                .frame(
                    width: r * 2.4,
                    height: r * 2.4
                )
                .blur(radius: r * 0.25)
                .opacity(0.35)
            
            // ✅ 核心能量体（不缩放）
            Circle()
                .fill(circle.color)
                .frame(
                    width: r * 2,
                    height: r * 2
                )
                .opacity(0.92)
        }
    }
}

// MARK: - ✅ Apple 锁屏级空间背景（白黑自动适配）

extension ColorEmergeSpaceDemoView {
    
    private var appleSpaceBackground: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // 顶部微亮（空间纵深）
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.05),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            // 底部微暗（空间厚度）
            LinearGradient(
                colors: [
                    .clear,
                    Color.primary.opacity(0.06)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - ✅ Preview

#if DEBUG
struct ColorEmergeSpaceDemoView_Previews: PreviewProvider {
    static var previews: some View {
        ColorEmergeSpaceDemoView()
    }
}
#endif
