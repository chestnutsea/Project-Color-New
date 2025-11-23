import SwiftUI

struct DeepBlueSoftGlowView: View {
    @State private var particles = Particle.makeParticles(count: 5)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // 更新每个粒子（必须写 inside Canvas 才会刷新）
                for i in particles.indices {
                    particles[i].update(time: time, size: size)
                }

                // 绘制每个粒子
                for p in particles {
                    for layer in stride(from: 12, to: 0, by: -1) {
                        let progress = Double(layer) / 12.0
                        let alpha = progress * 0.22
                        let rect = CGRect(
                            x: p.position.x - p.radius * CGFloat(layer) * 0.15,
                            y: p.position.y - p.radius * CGFloat(layer) * 0.15,
                            width: p.radius * CGFloat(layer) * 0.30,
                            height: p.radius * CGFloat(layer) * 0.30
                        )

                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(p.color.opacity(alpha))
                        )
                    }
                }
            }
            .ignoresSafeArea()
            .background(Color.black.opacity(0.08))
        }
    }
}


// ------------------------------------
// MARK: - Particle Model
// ------------------------------------

struct Particle {
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var color: Color
    var noiseOffset: Double

    // 色彩：淡蓝、天蓝、蔚蓝、暗橙、紫红
    static let palette: [Color] = [
        Color(red: 0.78, green: 0.88, blue: 1.00),
        Color(red: 0.50, green: 0.72, blue: 1.00),
        Color(red: 0.18, green: 0.36, blue: 0.86),
        Color(red: 1.00, green: 0.55, blue: 0.18),
        Color(red: 0.74, green: 0.18, blue: 0.48)
    ]

    static func makeParticles(count: Int) -> [Particle] {
        (0..<count).map { _ in
            Particle(
                position: CGPoint(x: .random(in: 0...400),
                                  y: .random(in: 0...800)),
                velocity: CGVector(dx: .random(in: -0.20...0.20),
                                   dy: .random(in: -0.20...0.20)),
                radius: CGFloat.random(in: 40...80),
                color: palette.randomElement()!,
                noiseOffset: Double.random(in: 0...1000)
            )
        }
    }

    // ------------------------------------
    // MARK: 更新（含轻柔反弹逻辑）
    // ------------------------------------
    mutating func update(time: Double, size: CGSize) {
        let n1 = slowNoise(x: noiseOffset,      y: time * 0.03)
        let n2 = slowNoise(x: noiseOffset + 40, y: time * 0.03)

        // 噪声微变化
        velocity.dx += (n1 - 0.5) * 0.006
        velocity.dy += (n2 - 0.5) * 0.006

        position.x += velocity.dx
        position.y += velocity.dy

        // 轻柔反弹（不是穿越）
        let damping = 0.8   // 阻尼，让反弹更柔和

        // 左侧
        if position.x < radius {
            position.x = radius
            velocity.dx = abs(velocity.dx) * damping
        }
        // 右侧
        if position.x > size.width - radius {
            position.x = size.width - radius
            velocity.dx = -abs(velocity.dx) * damping
        }
        // 上
        if position.y < radius {
            position.y = radius
            velocity.dy = abs(velocity.dy) * damping
        }
        // 下
        if position.y > size.height - radius {
            position.y = size.height - radius
            velocity.dy = -abs(velocity.dy) * damping
        }
    }
}


// ------------------------------------
// MARK: - Slow Noise
// ------------------------------------

func slowNoise(x: Double, y: Double) -> Double {
    let v = sin(x * 0.7 + y * 0.5) + cos(x * 0.3 - y * 0.8)
    return (v + 2) / 4
}


// ------------------------------------

struct DeepBlueSoftGlowView_Previews: PreviewProvider {
    static var previews: some View {
        DeepBlueSoftGlowView()
    }
}
