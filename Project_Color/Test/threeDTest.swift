import SwiftUI
import CoreGraphics

struct ColorSpacePoint: Identifiable {
    let id = UUID()
    let rgb: SIMD3<Float>
    let weight: Double    // 0 ~ 1
    let label: String
    
    var cgColor: CGColor {
        let components: [CGFloat] = [
            CGFloat(rgb.x),
            CGFloat(rgb.y),
            CGFloat(rgb.z),
            1.0
        ]
        return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: components) ?? CGColor(gray: 1.0, alpha: 1.0)
    }
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
        
        // 摄像机
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 400)
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
        
        cameraNode.look(at: SCNVector3(0, 0, 0))
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = uiView.scene else { return }
        rebuildColorNodes(in: scene)
    }
    
    // MARK: - 工具函数
    private func colorToPosition(_ rgb: SIMD3<Float>) -> SCNVector3 {
        let edgeLength = Float(LayoutConstants.cubeEdgeWidth)
        let half = edgeLength / 2
        let x = rgb.x * edgeLength - half
        let y = rgb.y * edgeLength - half
        let z = rgb.z * edgeLength - half
        return SCNVector3(x, y, z)
    }

    private func addBoundingCube(to scene: SCNScene) {
        if scene.rootNode.childNode(withName: "boundingCube", recursively: false) != nil {
            return
        }
        
        let cube = SCNBox(
            width: LayoutConstants.cubeEdgeWidth,
            height: LayoutConstants.cubeEdgeWidth,
            length: LayoutConstants.cubeEdgeWidth,
            chamferRadius: 0
        )
        let cubeMaterial = SCNMaterial()
        cubeMaterial.diffuse.contents = LayoutConstants.cubeEdgeColor
        cubeMaterial.fillMode = .lines
        cube.firstMaterial = cubeMaterial
        
        let cubeNode = SCNNode(geometry: cube)
        cubeNode.name = "boundingCube"
        scene.rootNode.addChildNode(cubeNode)
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
            sphere.firstMaterial?.diffuse.contents = point.cgColor
            sphere.firstMaterial?.lightingModel = .constant
            
            let node = SCNNode(geometry: sphere)
            node.position = colorToPosition(point.rgb)
            node.name = point.label
            containerNode.addChildNode(node)
        }
    }
    
    
    private func makeAxisHelper(length: CGFloat) -> SCNNode {
        let node = SCNNode()
        func line(from: SCNVector3, to: SCNVector3, color: CGColor) -> SCNNode {
            let source = SCNGeometrySource(vertices: [from, to])
            let indices: [Int32] = [0, 1]
            let element = SCNGeometryElement(indices: indices, primitiveType: .line)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            geometry.firstMaterial?.diffuse.contents = color
            return SCNNode(geometry: geometry)
        }
        let origin = SCNVector3(0, 0, 0)
        node.addChildNode(line(from: origin, to: SCNVector3(Float(length/2), 0, 0), color: CGColor(red: 1, green: 0, blue: 0, alpha: 1)))
        node.addChildNode(line(from: origin, to: SCNVector3(0, Float(length/2), 0), color: CGColor(red: 0, green: 1, blue: 0, alpha: 1)))
        node.addChildNode(line(from: origin, to: SCNVector3(0, 0, Float(length/2)), color: CGColor(red: 0, green: 0, blue: 1, alpha: 1)))
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
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColorInfo: String? = nil
    
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
        }
        .animation(.easeInOut, value: selectedColorInfo)
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .padding(10)
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
                Text("完成色彩分析后，将可在此查看所有主色在 RGB 空间中的分布。")
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
        ColorSpacePoint(rgb: SIMD3<Float>(0.95, 0.25, 0.25), weight: 0.35, label: "#F24040 • 35%"),
        ColorSpacePoint(rgb: SIMD3<Float>(0.20, 0.80, 0.40), weight: 0.25, label: "#33CC66 • 25%"),
        ColorSpacePoint(rgb: SIMD3<Float>(0.10, 0.60, 1.00), weight: 0.20, label: "#1A99FF • 20%"),
        ColorSpacePoint(rgb: SIMD3<Float>(0.95, 0.82, 0.10), weight: 0.15, label: "#F2D119 • 15%"),
        ColorSpacePoint(rgb: SIMD3<Float>(0.80, 0.20, 0.80), weight: 0.05, label: "#CC33CC • 5%")
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
