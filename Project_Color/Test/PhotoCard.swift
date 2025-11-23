import SwiftUI

struct PhotoCardDemo: View {
    var body: some View {
        ZStack {
            Color(white: 0.95).ignoresSafeArea()
            PhotoCard()
        }
    }
}

struct PhotoCard: View {
    @State private var offset: CGSize = .zero
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @GestureState private var isPressing = false
    
    var body: some View {
        let drag = DragGesture()
            .updating($isPressing) { _, state, _ in
                state = true
            }
            .onChanged { value in
                offset = value.translation
                rotationY = Double(value.translation.width / 12)
                rotationX = Double(-value.translation.height / 12)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    offset = .zero
                    rotationX = 0
                    rotationY = 0
                }
            }
        
        ZStack {
            // 底层照片色块
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.85))

            // 照片边框（像真实照片洗出来的白边）
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 10)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 8)

            // 浅反光层（照片表面的光泽）
            LinearGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .aspectRatio(4/3, contentMode: .fit)
        .frame(width: 270)
        .scaleEffect(isPressing ? 0.97 : 1)  // 手指压着时轻微缩放
        .offset(offset)
        .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))
        .animation(.interactiveSpring(), value: offset)
        .gesture(drag)
    }
}

#Preview {
    PhotoCardDemo()
}
