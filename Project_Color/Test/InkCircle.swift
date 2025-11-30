import SwiftUI

struct MetaballDemoView: View {

    struct Blob: Identifiable {
        let id = UUID()
        var center: CGPoint
        var radius: CGFloat
        var color: Color
        var targetOffset: CGSize
    }

    @State private var blobs: [Blob] = []
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Canvas { context, size in
                    // ✅ 先做 alpha 阈值，再模糊，标准 metaball 管线
                    context.addFilter(.alphaThreshold(min: 0.5))
                    context.addFilter(.blur(radius: 30))

                    context.drawLayer { layer in
                        for blob in blobs {
                            let rect = CGRect(
                                x: blob.center.x - blob.radius,
                                y: blob.center.y - blob.radius,
                                width: blob.radius * 2,
                                height: blob.radius * 2
                            )

                            layer.fill(
                                Path(ellipseIn: rect),
                                with: .color(.white) // 先用白色做“密度场”
                            )
                        }
                    }
                }
                .overlay {
                    // ✅ 再铺一层彩色圆，只负责上色，不影响形状
                    ZStack {
                        ForEach(blobs) { blob in
                            Circle()
                                .fill(blob.color)
                                .frame(width: blob.radius * 2, height: blob.radius * 2)
                                .position(blob.center)
                        }
                    }
                    .blendMode(.softLight)
                }
            }
            .onAppear {
                setupBlobs(in: geo.size)
                startAnimation(in: geo.size)
            }
        }
    }

    // 初始化几个球的位置
    private func setupBlobs(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        blobs = [
            Blob(
                center: center,
                radius: 120,
                color: .yellow,
                targetOffset: .zero
            ),
            Blob(
                center: CGPoint(x: center.x, y: center.y - 140),
                radius: 90,
                color: .blue,
                targetOffset: .zero
            ),
            Blob(
                center: CGPoint(x: center.x + 180, y: center.y - 220),
                radius: 70,
                color: .red,
                targetOffset: .zero
            ),
            Blob(
                center: CGPoint(x: center.x - 180, y: center.y - 220),
                radius: 70,
                color: .white,
                targetOffset: .zero
            )
        ]
    }

    // 随机漂浮动画（隐式动画 + 位置插值）
    private func startAnimation(in size: CGSize) {
        withAnimation(
            .easeInOut(duration: 8)
            .repeatForever(autoreverses: true)
        ) {
            for index in blobs.indices {
                blobs[index].center.x += CGFloat.random(in: -80...80)
                blobs[index].center.y += CGFloat.random(in: -60...60)
            }
        }
    }
}

#Preview {
    MetaballDemoView()
}
