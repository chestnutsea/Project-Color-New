//
//  ColorMist.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/23.
//

import SwiftUI
import SceneKit

// MARK: - 数据模型

struct ColorPoint {
    let x: Float   // 0...1
    let y: Float   // 0...1
    let z: Float   // 0...1
    let color: UIColor
    let size: CGFloat
}

// MARK: - 生成一些伪数据，模拟 LCh/Lab 点云

struct ColorPointMock {
    static func sampleCloud() -> [ColorPoint] {
        var points: [ColorPoint] = []

        // 一团偏暖、低饱和、接近地面的点（类似你图里左下那坨）
        for i in 0..<60 {
            let t = Float(i) / 60.0
            let x = Float.random(in: 0.15...0.4) + t * 0.05      // H-ish
            let y = Float.random(in: 0.1...0.35)                 // L-ish
            let z = Float.random(in: 0.05...0.3)                 // C-ish

            let hue = CGFloat(0.05 + Double.random(in: -0.02...0.02))  // 偏黄
            let sat = CGFloat(Double.random(in: 0.3...0.6))
            let bri = CGFloat(Double.random(in: 0.4...0.8))
            let uiColor = UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 1.0)

            let size: CGFloat = CGFloat.random(in: 0.004...0.009)

            points.append(ColorPoint(x: x, y: y, z: z, color: uiColor, size: size))
        }

        // 一些偏绿 / 蓝的孤立点（右边那一撮）
        for _ in 0..<15 {
            let x = Float.random(in: 0.55...0.9)
            let y = Float.random(in: 0.15...0.5)
            let z = Float.random(in: 0.05...0.35)

            let hue = CGFloat(Double.random(in: 0.5...0.7))     // 青到蓝
            let sat = CGFloat(Double.random(in: 0.3...0.7))
            let bri = CGFloat(Double.random(in: 0.5...0.9))
            let uiColor = UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 1.0)

            let size: CGFloat = CGFloat.random(in: 0.004...0.01)
            points.append(ColorPoint(x: x, y: y, z: z, color: uiColor, size: size))
        }

        // 几个特别亮的点作为“高亮色”
        for _ in 0..<6 {
            let x = Float.random(in: 0.3...0.6)
            let y = Float.random(in: 0.4...0.7)
            let z = Float.random(in: 0.15...0.4)

            let hue = CGFloat(Double.random(in: 0.1...0.18))
            let uiColor = UIColor(hue: hue, saturation: 0.7, brightness: 1.0, alpha: 1.0)
            let size: CGFloat = CGFloat.random(in: 0.008...0.013)

            points.append(ColorPoint(x: x, y: y, z: z, color: uiColor, size: size))
        }

        return points
    }
}

// MARK: - SceneKit 场景构建

final class ColorPointCloudSceneBuilder {
    static func makeScene(points: [ColorPoint]) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        // 坐标系中心设为 (0,0,0)，把 0...1 的点挪到 [-0.5,0.5]
        let root = scene.rootNode

        // 添加点
        for p in points {
            let sphere = SCNSphere(radius: p.size)
            sphere.segmentCount = 16
            let material = SCNMaterial()
            material.diffuse.contents = p.color
            material.lightingModel = .phong
            material.specular.contents = UIColor(white: 0.8, alpha: 1.0)
            sphere.materials = [material]

            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(
                p.x - 0.5,
                p.y - 0.5,
                p.z - 0.5
            )
            root.addChildNode(node)
        }

        // 坐标轴：H, L, C 三个轴线
        addAxes(to: root)

        // 相机
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.5, 0.5, 1.6)
        let constraint = SCNLookAtConstraint(target: root)
        constraint.isGimbalLockEnabled = true
        cameraNode.constraints = [constraint]
        scene.rootNode.addChildNode(cameraNode)

        // 灯光（环境 + 一盏主灯）
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 400
        ambient.color = UIColor(white: 0.7, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)

        let omni = SCNLight()
        omni.type = .omni
        omni.intensity = 800
        let omniNode = SCNNode()
        omniNode.light = omni
        omniNode.position = SCNVector3(0.8, 1.0, 1.5)
        root.addChildNode(omniNode)

        // 整体缓慢自转（如果你想静止可以注释掉这几行）
        let rotate = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 40)
        )
        root.runAction(rotate)

        return scene
    }

    private static func addAxes(to root: SCNNode) {
        let axisLength: CGFloat = 1.0
        let axisRadius: CGFloat = 0.002

        func makeAxisNode(length: CGFloat, color: UIColor) -> SCNNode {
            let cylinder = SCNCylinder(radius: axisRadius, height: length)
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.emission.contents = color
            cylinder.materials = [material]
            let node = SCNNode(geometry: cylinder)
            return node
        }

        // L 轴（Y 轴）
        let lAxis = makeAxisNode(length: axisLength, color: .white)
        lAxis.position = SCNVector3(0, axisLength / 2 - 0.5, 0)
        root.addChildNode(lAxis)

        // H 轴（X 轴）
        let hAxis = makeAxisNode(length: axisLength, color: .white)
        hAxis.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        hAxis.position = SCNVector3(axisLength / 2 - 0.5, 0, 0)
        root.addChildNode(hAxis)

        // C 轴（Z 轴）
        let cAxis = makeAxisNode(length: axisLength, color: .white)
        cAxis.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        cAxis.position = SCNVector3(0, 0, axisLength / 2 - 0.5)
        root.addChildNode(cAxis)

        // 轴文字（简单放三个字母）
        func makeTextNode(_ text: String, position: SCNVector3) -> SCNNode {
            let textGeo = SCNText(string: text, extrusionDepth: 0.01)
            textGeo.font = UIFont.systemFont(ofSize: 0.08, weight: .regular)
            textGeo.firstMaterial?.diffuse.contents = UIColor.white
            let node = SCNNode(geometry: textGeo)
            node.scale = SCNVector3(0.1, 0.1, 0.1)
            node.position = position
            return node
        }

        root.addChildNode(makeTextNode("L", position: SCNVector3(-0.58, 0.5, -0.5)))
        root.addChildNode(makeTextNode("H", position: SCNVector3(0.5, -0.58, -0.5)))
        root.addChildNode(makeTextNode("C", position: SCNVector3(-0.58, -0.5, 0.5)))
    }
}

// MARK: - SwiftUI 封装

struct ColorPointCloudSceneView: UIViewRepresentable {
    let points: [ColorPoint]

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = ColorPointCloudSceneBuilder.makeScene(points: points)
        view.allowsCameraControl = true   // 手势旋转/缩放
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 60
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // 这里暂时不需要动态更新
    }
}

// MARK: - SwiftUI 容器 + 预览

struct ColorPointCloudContainer: View {
    private let points = ColorPointMock.sampleCloud()

    var body: some View {
        ColorPointCloudSceneView(points: points)
            .ignoresSafeArea()
            .background(Color.black)
    }
}

struct ColorPointCloudContainer_Previews: PreviewProvider {
    static var previews: some View {
        ColorPointCloudContainer()
    }
}
