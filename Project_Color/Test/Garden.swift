//
//  Garden.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/12/21.
//

import SwiftUI

// MARK: - Layout Constants

private enum GardenLayout {
    static let stemHeightRatio: CGFloat = 0.98  // 茎的高度占完整高度的比例（避免穿过花心）
}

// MARK: - Main View

struct SwayingGardenView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            GardenScene(count: 20)
        }
    }
}

// MARK: - Scene

struct GardenScene: View {
    let count: Int
    private let stems: [StemSpec]
    private let startTime = Date()

    init(count: Int) {
        self.count = count
        var rng = SeededGenerator(seed: 20251221)
        self.stems = (0..<count).map { i in
            StemSpec.make(index: i, rng: &rng)
        }
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(startTime)

                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    let groundY = h * 0.97

                    for stem in stems {
                        drawStemAndFlower(
                            context: &context,
                            size: size,
                            time: t,
                            groundY: groundY,
                            stem: stem
                        )
                    }
                }
            }
        }
    }

    // MARK: - Drawing

    private func drawStemAndFlower(
        context: inout GraphicsContext,
        size: CGSize,
        time t: TimeInterval,
        groundY: CGFloat,
        stem: StemSpec
    ) {
        let x = size.width * stem.x01
        let maxHeight = size.height * stem.height01

        // 生长进度（0 → 1）
        let growT = max(0, min(1, (t - stem.growDelay) / stem.growDuration))
        let growth = easeOutCubic(growT)

        let currentHeight = maxHeight * growth

        // 摇曳：生长阶段较弱，成熟后增强
        let swayStrength = lerp(0.25, 1.0, growth)
        let sway =
            (sin(t * stem.swaySpeed + stem.phase) +
             0.6 * sin(t * stem.swaySpeed * 0.61 + stem.phase * 1.8))
            * stem.swayAmplitude
            * swayStrength

        let base = CGPoint(x: x, y: groundY)
        // 茎的顶端比花朵位置低一点，避免穿过花心
        let stemTop = CGPoint(x: x + sway, y: groundY - currentHeight * GardenLayout.stemHeightRatio)
        let flowerTop = CGPoint(x: x + sway, y: groundY - currentHeight)

        let c1 = CGPoint(
            x: x + sway * 0.15,
            y: groundY - currentHeight * 0.35
        )
        let c2 = CGPoint(
            x: x + sway * 0.65,
            y: groundY - currentHeight * 0.70
        )

        // 茎（终点在 stemTop，比花朵低）
        if currentHeight > 1 {
            var path = Path()
            path.move(to: base)
            path.addCurve(to: stemTop, control1: c1, control2: c2)

            context.stroke(
                path,
                with: .color(stem.color.opacity(0.9)),
                lineWidth: stem.stemWidth
            )
        }

        // 花朵开放进度（在茎长到 65% 之后）
        let bloomStart: CGFloat = 0.65
        let bloomT = max(0, min(1, (growth - bloomStart) / (1 - bloomStart)))

        if bloomT > 0 {
            drawFlower(
                context: &context,
                center: flowerTop,
                bloom: bloomT,
                time: t,
                stem: stem
            )
        }
    }

    private func drawFlower(
        context: inout GraphicsContext,
        center: CGPoint,
        bloom: CGFloat,
        time t: TimeInterval,
        stem: StemSpec
    ) {
        let bloomEase = easeOutBack(bloom)

        let rotation = sin(t * stem.swaySpeed + stem.phase) * 0.3
        let petalCount = stem.petalCount

        let petalRadius = stem.flowerSize * bloomEase
        let petalLength = stem.flowerSize * 1.4 * bloomEase

        for i in 0..<petalCount {
            let angle =
                Double(i) / Double(petalCount) * .pi * 2
                + rotation

            let dir = CGVector(dx: cos(angle), dy: sin(angle))
            let petalCenter = CGPoint(
                x: center.x + dir.dx * petalRadius,
                y: center.y + dir.dy * petalRadius
            )

            // 使用 GraphicsContext 的变换方式
            var petalContext = context
            petalContext.translateBy(x: petalCenter.x, y: petalCenter.y)
            petalContext.rotate(by: .radians(angle))

            let rect = CGRect(
                x: -petalLength * 0.5,
                y: -stem.flowerSize * 0.45,
                width: petalLength,
                height: stem.flowerSize * 0.9
            )

            let petal = Path(ellipseIn: rect)
            petalContext.fill(petal, with: .color(stem.color.opacity(0.95)))
            petalContext.stroke(
                petal,
                with: .color(stem.color.opacity(0.4)),
                lineWidth: 1
            )
        }
        
        // 花心（透明，不绘制）
        // let coreR = stem.flowerSize * 0.25 * bloomEase
        // let coreRect = CGRect(
        //     x: center.x - coreR,
        //     y: center.y - coreR,
        //     width: coreR * 2,
        //     height: coreR * 2
        // )
        // context.fill(Path(ellipseIn: coreRect), with: .color(.clear))
    }
}

// MARK: - Preview

#Preview {
    SwayingGardenView()
        .frame(width: 390, height: 844)
}

// MARK: - Model

struct StemSpec: Identifiable {
    let id: Int
    let x01: CGFloat
    let height01: CGFloat
    let color: Color
    let stemWidth: CGFloat

    let swayAmplitude: CGFloat
    let swaySpeed: Double
    let phase: Double

    let flowerSize: CGFloat
    let petalCount: Int

    let growDelay: TimeInterval
    let growDuration: TimeInterval

    static func make(index: Int, rng: inout SeededGenerator) -> StemSpec {
        StemSpec(
            id: index,
            x01: (CGFloat(index) + 0.5) / 20
                + rng.nextCGFloat(in: -0.02...0.02),
            height01: rng.nextCGFloat(in: 0.4...0.85),
            color: Color(
                hue: rng.nextDouble(in: 0...1),
                saturation: rng.nextDouble(in: 0.65...0.95),
                brightness: rng.nextDouble(in: 0.75...0.98)
            ),
            stemWidth: rng.nextCGFloat(in: 1.5...3),
            swayAmplitude: rng.nextCGFloat(in: 12...32),
            swaySpeed: rng.nextDouble(in: 0.6...1.6),
            phase: rng.nextDouble(in: 0...(.pi * 2)),
            flowerSize: rng.nextCGFloat(in: 10...22),
            petalCount: Int(rng.nextDouble(in: 5...9)),
            growDelay: rng.nextDouble(in: 0...1.5),
            growDuration: rng.nextDouble(in: 2.5...4.5)
        )
    }
}

// MARK: - Utilities

func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

func easeOutCubic(_ t: CGFloat) -> CGFloat {
    1 - pow(1 - t, 3)
}

func easeOutBack(_ t: CGFloat) -> CGFloat {
    let c1: CGFloat = 1.70158
    let c3 = c1 + 1
    return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
}

// MARK: - Seeded RNG

struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func nextUInt64() -> UInt64 {
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }

    mutating func nextDouble() -> Double {
        Double(nextUInt64() >> 11) / Double(1 << 53)
    }

    mutating func nextDouble(in r: ClosedRange<Double>) -> Double {
        r.lowerBound + (r.upperBound - r.lowerBound) * nextDouble()
    }

    mutating func nextCGFloat(in r: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(nextDouble(in: Double(r.lowerBound)...Double(r.upperBound)))
    }
}

#Preview {
    SwayingGardenView()
}
