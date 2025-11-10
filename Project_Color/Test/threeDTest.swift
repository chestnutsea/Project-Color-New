import SwiftUI
import SceneKit
import UIKit

// MARK: - 布局常量
private struct LayoutConstants {
    static let cubeEdgeColor = UIColor(white: 1.0, alpha: 0.8) // 外框线颜色
    static let cubeEdgeWidth: CGFloat = 160                     // 立方体边长（RGB范围）
    static let sphereRadius: CGFloat = 2                        // 每个点的半径
}

// MARK: - 主 3D 视图
struct ColorSpace3DView: UIViewRepresentable {
    var colors: [UIColor]
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
        ambientLight.light?.color = UIColor(white: 0.6, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.color = UIColor.white
        lightNode.position = SCNVector3(300, 300, 500)
        scene.rootNode.addChildNode(lightNode)
        
        // 坐标轴
        scene.rootNode.addChildNode(makeAxisHelper(length: LayoutConstants.cubeEdgeWidth))
        
        // 外框立方体
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
        scene.rootNode.addChildNode(cubeNode)
        
        // 添加颜色点
        for color in colors {
            let sphere = SCNSphere(radius: LayoutConstants.sphereRadius)
            sphere.firstMaterial?.diffuse.contents = color
            sphere.firstMaterial?.lightingModel = .constant
            
            let node = SCNNode(geometry: sphere)
            node.position = colorToPosition(color)
            node.name = colorToHex(color)
            scene.rootNode.addChildNode(node)
        }
        
        // 点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        cameraNode.look(at: SCNVector3(0, 0, 0))
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    // MARK: - 工具函数
    private func colorToPosition(_ color: UIColor) -> SCNVector3 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // 自动按立方体边长映射
        let edgeLength = Float(LayoutConstants.cubeEdgeWidth)
        let half = edgeLength / 2
        let x = Float(r) * edgeLength - half
        let y = Float(g) * edgeLength - half
        let z = Float(b) * edgeLength - half
        return SCNVector3(x, y, z)
    }

    
    private func makeAxisHelper(length: CGFloat) -> SCNNode {
        let node = SCNNode()
        func line(from: SCNVector3, to: SCNVector3, color: UIColor) -> SCNNode {
            let source = SCNGeometrySource(vertices: [from, to])
            let indices: [Int32] = [0, 1]
            let element = SCNGeometryElement(indices: indices, primitiveType: .line)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            geometry.firstMaterial?.diffuse.contents = color
            return SCNNode(geometry: geometry)
        }
        let origin = SCNVector3(0, 0, 0)
        node.addChildNode(line(from: origin, to: SCNVector3(Float(length/2), 0, 0), color: .red))
        node.addChildNode(line(from: origin, to: SCNVector3(0, Float(length/2), 0), color: .green))
        node.addChildNode(line(from: origin, to: SCNVector3(0, 0, Float(length/2)), color: .blue))
        return node
    }
    
    private func colorToHex(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X (R:%.0f, G:%.0f, B:%.0f)",
                      Int(r*255), Int(g*255), Int(b*255), r*255, g*255, b*255)
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
    @State private var selectedColorInfo: String? = nil
    
    let sampleColors: [UIColor] = [
        UIColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 1),
        UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1),
        UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1),
        UIColor(red: 0.9, green: 0.8, blue: 0.1, alpha: 1),
        UIColor(red: 0.8, green: 0.2, blue: 0.8, alpha: 1),
        UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1),
        UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1),
        UIColor(red: 0.0, green: 0.9, blue: 0.7, alpha: 1),
        UIColor(red: 0.3, green: 0.3, blue: 1.0, alpha: 1),
        UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
    ]
    
    var body: some View {
        ZStack {
            sceneView
            colorInfoOverlay
        }
        .animation(.easeInOut, value: selectedColorInfo)
    }
    
    private var sceneView: some View {
        ColorSpace3DView(colors: sampleColors, selectedColorInfo: $selectedColorInfo)
            .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var colorInfoOverlay: some View {
        if let info = selectedColorInfo {
            VStack {
                Text(info)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .foregroundStyle(.white)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .padding(.top, 50)
                Spacer()
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    threeDView()
}
