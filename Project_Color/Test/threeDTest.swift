import SwiftUI
import CoreGraphics
import simd

struct ColorSpacePoint: Identifiable {
    let id = UUID()
    let position: SIMD3<Float>   // Normalized LCh coordinates in [-0.5, 0.5]: (h, C, L)
    let weight: Double           // 0 ~ 1
    let label: String
    let displayColor: CGColor
}

#if os(iOS) || os(tvOS) || os(visionOS)

import SceneKit
import UIKit

// MARK: - 布局常量
private struct LayoutConstants {
    static let cubeEdgeColor = CGColor(gray: 1.0, alpha: 0.8)   // 外框线颜色
    static let cubeEdgeWidth: CGFloat = 160                     // 立方体边长（RGB范围）
    static let minSphereRadius: CGFloat = 1.6                   // 最小球体半径
    static let maxSphereRadius: CGFloat = 5.5                   // 最大球体半径
    static let nodeContainerName = "colorPointContainer"
}

// MARK: - 主 3D 视图
struct ColorSpace3DView: UIViewRepresentable {
    var points: [ColorSpacePoint]
    @Binding var selectedColorInfo: String?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        
        let scene = SCNScene()
        scnView.scene = scene
        
        // 摄像机 - 调整位置以观察第一象限
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        let halfEdge = Float(LayoutConstants.cubeEdgeWidth) / 2.0
        // 摄像机位于第一象限外侧，斜向观察立方体中心
        cameraNode.position = SCNVector3(halfEdge + 200, halfEdge + 200, halfEdge + 400)
        cameraNode.camera?.zFar = 1000
        scene.rootNode.addChildNode(cameraNode)
        
        // 光照
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = CGColor(gray: 0.6, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.color = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        lightNode.position = SCNVector3(300, 300, 500)
        scene.rootNode.addChildNode(lightNode)
        
        // 坐标轴
        scene.rootNode.addChildNode(makeAxisHelper(length: LayoutConstants.cubeEdgeWidth))
        
        addBoundingCube(to: scene)
        rebuildColorNodes(in: scene)
        
        // 点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        // 让摄像机看向立方体中心
        cameraNode.look(at: SCNVector3(halfEdge, halfEdge, halfEdge))
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = uiView.scene else { return }
        rebuildColorNodes(in: scene)
    }
    
    // MARK: - 工具函数
    private func colorToPosition(_ normalizedLCh: SIMD3<Float>) -> SCNVector3 {
        // normalizedLCh: (h, C, L) in [-0.5, 0.5]
        // 映射到第一象限：[0, edgeLength]
        // X = h (色相), Y = C (色度), Z = L (亮度)
        let edgeLength = Float(LayoutConstants.cubeEdgeWidth)
        let x = (normalizedLCh.x + 0.5) * edgeLength  // [-0.5, 0.5] → [0, edgeLength]
        let y = (normalizedLCh.y + 0.5) * edgeLength  // [-0.5, 0.5] → [0, edgeLength]
        let z = (normalizedLCh.z + 0.5) * edgeLength  // [-0.5, 0.5] → [0, edgeLength]
        return SCNVector3(x, y, z)
    }

    private func addBoundingCube(to scene: SCNScene) {
        // 不再添加正方体边框，只保留 LCh 三轴
        // 坐标轴已经在 makeAxisHelper 中创建
    }
    
    private func rebuildColorNodes(in scene: SCNScene) {
        let containerNode: SCNNode
        if let existing = scene.rootNode.childNode(withName: LayoutConstants.nodeContainerName, recursively: false) {
            existing.childNodes.forEach { $0.removeFromParentNode() }
            containerNode = existing
        } else {
            let newNode = SCNNode()
            newNode.name = LayoutConstants.nodeContainerName
            scene.rootNode.addChildNode(newNode)
            containerNode = newNode
        }
        
        guard !points.isEmpty else { return }
        
        for point in points {
            let clampedWeight = max(0.0, min(1.0, point.weight))
            let radius = LayoutConstants.minSphereRadius + CGFloat(clampedWeight) * (LayoutConstants.maxSphereRadius - LayoutConstants.minSphereRadius)
            
            let sphere = SCNSphere(radius: radius)
            sphere.firstMaterial?.diffuse.contents = point.displayColor
            sphere.firstMaterial?.lightingModel = .constant
            
            let node = SCNNode(geometry: sphere)
            node.position = colorToPosition(point.position)
            node.name = point.label
            containerNode.addChildNode(node)
        }
    }
    
    
    private func makeAxisHelper(length: CGFloat) -> SCNNode {
        let node = SCNNode()
        let axisColor = CGColor(gray: 0.8, alpha: 1.0)  // 统一的轴颜色
        
        func line(from: SCNVector3, to: SCNVector3, color: CGColor) -> SCNNode {
            let source = SCNGeometrySource(vertices: [from, to])
            let indices: [Int32] = [0, 1]
            let element = SCNGeometryElement(indices: indices, primitiveType: .line)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            geometry.firstMaterial?.diffuse.contents = color
            return SCNNode(geometry: geometry)
        }
        
        func makeAxisLabel(text: String, position: SCNVector3) -> SCNNode {
            let textGeometry = SCNText(string: text, extrusionDepth: 0)
            textGeometry.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            textGeometry.flatness = 0.1
            textGeometry.firstMaterial?.diffuse.contents = UIColor.white
            textGeometry.firstMaterial?.lightingModel = .constant
            
            let textNode = SCNNode(geometry: textGeometry)
            textNode.position = position
            textNode.scale = SCNVector3(0.5, 0.5, 0.5)
            
            // 让文字始终面向摄像机
            textNode.constraints = [SCNBillboardConstraint()]
            
            return textNode
        }
        
        let axisLength = Float(length)
        
        // X 轴 (H - 色相) - 从原点到正方向
        node.addChildNode(line(from: SCNVector3(0, 0, 0), to: SCNVector3(axisLength, 0, 0), color: axisColor))
        node.addChildNode(makeAxisLabel(text: "H", position: SCNVector3(axisLength + 15, 0, 0)))
        
        // Y 轴 (C - 色度) - 从原点到正方向
        node.addChildNode(line(from: SCNVector3(0, 0, 0), to: SCNVector3(0, axisLength, 0), color: axisColor))
        node.addChildNode(makeAxisLabel(text: "C", position: SCNVector3(0, axisLength + 15, 0)))
        
        // Z 轴 (L - 亮度) - 从原点到正方向
        node.addChildNode(line(from: SCNVector3(0, 0, 0), to: SCNVector3(0, 0, axisLength), color: axisColor))
        node.addChildNode(makeAxisLabel(text: "L", position: SCNVector3(0, 0, axisLength + 15)))
        
        return node
    }
    
    // MARK: - Coordinator（手势交互）
    class Coordinator: NSObject {
        var parent: ColorSpace3DView
        init(_ parent: ColorSpace3DView) { self.parent = parent }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            let hits = scnView.hitTest(gesture.location(in: scnView), options: nil)
            if let node = hits.first?.node, let name = node.name {
                DispatchQueue.main.async {
                    self.parent.selectedColorInfo = name
                }
            }
        }
    }
}

// MARK: - threeDView 容器
struct threeDView: View {
    private enum Layout {
        static let closeButtonFontSize: CGFloat = 16  // 关闭按钮字体大小（布局常量）
        static let closeButtonPadding: CGFloat = 8  // 关闭按钮内边距（布局常量）
        static let helpIconFontSize: CGFloat = 18  // 帮助图标字体大小（布局常量）
    }
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColorInfo: String? = nil
    @State private var showHelpText: Bool = false
    
    let points: [ColorSpacePoint]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if points.isEmpty {
                emptyStateOverlay
            } else {
                ColorSpace3DView(points: points, selectedColorInfo: $selectedColorInfo)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        colorInfoOverlay
                    }
            }
            
            closeButton
            
            // 右下角帮助按钮和说明文字（同一行）
            if !points.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Spacer()
                        
                        // 帮助说明文字（固定宽度，通过 opacity 控制显示/隐藏）
                        Text(L10n.ThreeDView.lchExplanation.localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                            .opacity(showHelpText ? 1 : 0)
                        
                        // 帮助图标按钮（固定位置）
                        Button(action: {
                            showHelpText.toggle()
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: Layout.helpIconFontSize))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(20)
                }
            }
        }
        .animation(.easeInOut, value: selectedColorInfo)
        .animation(.easeInOut(duration: 0.2), value: showHelpText)
    }
    
    @ViewBuilder
    private var colorInfoOverlay: some View {
        if let info = selectedColorInfo {
            Text(info)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .cornerRadius(10)
                .foregroundStyle(.primary)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.down")
                .font(.system(size: Layout.closeButtonFontSize, weight: .semibold))
                .foregroundColor(.primary)
                .padding(Layout.closeButtonPadding)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
                .padding(EdgeInsets(top: 20, leading: 20, bottom: 0, trailing: 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("关闭 3D 视图")
    }
    
    private var emptyStateOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)
                Text("暂无 3D 数据")
                    .font(.headline)
                Text("完成色彩分析后，将可在此查看所有主色在 LCh 色彩空间中的分布。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }
}

#Preview {
    let samplePoints: [ColorSpacePoint] = [
        ColorSpacePoint(position: SIMD3<Float>(0.15, -0.12, 0.18), weight: 0.35, label: "#F24040 • 35%", displayColor: CGColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 1.0)),
        ColorSpacePoint(position: SIMD3<Float>(0.10, 0.20, -0.08), weight: 0.25, label: "#33CC66 • 25%", displayColor: CGColor(red: 0.20, green: 0.80, blue: 0.40, alpha: 1.0)),
        ColorSpacePoint(position: SIMD3<Float>(0.05, -0.05, -0.22), weight: 0.20, label: "#1A99FF • 20%", displayColor: CGColor(red: 0.10, green: 0.60, blue: 1.00, alpha: 1.0)),
        ColorSpacePoint(position: SIMD3<Float>(0.22, 0.08, 0.12), weight: 0.15, label: "#F2D119 • 15%", displayColor: CGColor(red: 0.95, green: 0.82, blue: 0.10, alpha: 1.0)),
        ColorSpacePoint(position: SIMD3<Float>(0.05, -0.18, -0.05), weight: 0.05, label: "#CC33CC • 5%", displayColor: CGColor(red: 0.80, green: 0.20, blue: 0.80, alpha: 1.0))
    ]
    
    return threeDView(points: samplePoints)
}

#else

struct threeDView: View {
    let points: [ColorSpacePoint]
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("3D 视图仅在 iOS / tvOS / visionOS 可用")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#endif
