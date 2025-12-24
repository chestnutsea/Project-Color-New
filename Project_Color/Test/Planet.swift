import SwiftUI
import SceneKit
import CoreImage
import UIKit

// MARK: - SwiftUI View

struct PlanetView: View {
    @State private var scene: SCNScene?
    
    var body: some View {
        Group {
            if let scene = scene {
                SceneView(
                    scene: scene,
                    options: [.autoenablesDefaultLighting]
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            // 每次进入页面时重新生成场景
            scene = makeScene()
        }
    }

    // MARK: - Scene

    private func makeScene() -> SCNScene {
        let scene = SCNScene()

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 70  // 增加视野角度，看到更多内容
        cameraNode.position = SCNVector3(0, 0, 8)  // 拉近相机
        scene.rootNode.addChildNode(cameraNode)

        // Main Light
        let lightNode = SCNNode()
        let light = SCNLight()
        light.type = .omni
        light.intensity = 900
        lightNode.light = light
        lightNode.position = SCNVector3(6, 6, 6)
        scene.rootNode.addChildNode(lightNode)

        // Ambient Light
        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 200
        ambient.color = UIColor(white: 0.25, alpha: 1)
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // Planets - 随机数量和位置，确保在可见范围内
        let planetCount = Int.random(in: 3...5)
        let spacing: Float = 2.5  // 进一步减小间距
        let totalWidth = Float(planetCount - 1) * spacing
        let startX = -totalWidth / 2
        
        for i in 0..<planetCount {
            let planet = makePlanet()
            // 水平排列，进一步减小随机偏移范围
            let x = startX + Float(i) * spacing
            let y = Float.random(in: -0.8...0.8)  // 进一步减小垂直偏移
            let z = Float.random(in: -0.3...0.3)  // 进一步减小深度偏移
            planet.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(planet)
        }

        return scene
    }
}

// MARK: - Planet Factory

private func makePlanet() -> SCNNode {
    let radius = CGFloat.random(in: 0.5...0.9)  // 减小半径范围
    let sphere = SCNSphere(radius: radius)
    sphere.segmentCount = 300  // 进一步增加分段数，让位移更细腻

    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    material.diffuse.contents = randomBaseColor()
    material.metalness.contents = 0.05

    // ⭐ 共享高度噪声（结构核心）
    let heightImage = generateHeightNoise(size: 1024)  // 提高到 1024，增加细节密度
    let heightUIImage = convertToUIImage(heightImage)

    // 使用位移贴图创造真实的几何凹凸
    material.displacement.contents = heightUIImage
    material.displacement.intensity = 0.08  // 降低位移强度，避免过度变形
    
    material.normal.contents = generateNormalMap(from: heightImage)
    material.normal.intensity = 1.5  // 适度的法线强度
    material.roughness.contents = generateRoughnessMap(from: heightImage)

    sphere.firstMaterial = material

    let node = SCNNode(geometry: sphere)

    let rotation = SCNAction.repeatForever(
        .rotateBy(x: 0, y: CGFloat.pi * 2, z: 0,
                  duration: Double.random(in: 14...26))
    )
    node.runAction(rotation)

    return node
}

// MARK: - Helper: Convert CIImage to UIImage

private func convertToUIImage(_ ciImage: CIImage) -> UIImage {
    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
        return UIImage()
    }
    return UIImage(cgImage: cgImage)
}

// MARK: - Core Image Context

private let ciContext = CIContext()

// MARK: - Height Noise

private func generateHeightNoise(size: Int) -> CIImage {
    guard let random = CIFilter(name: "CIRandomGenerator")?
        .outputImage?
        .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
    else {
        fatalError("Failed to create random noise")
    }

    // 多层噪声叠加，创造更复杂的凹凸效果
    guard let blur1 = CIFilter(name: "CIGaussianBlur"),
          let blur2 = CIFilter(name: "CIGaussianBlur"),
          let blur3 = CIFilter(name: "CIGaussianBlur"),
          let blur4 = CIFilter(name: "CIGaussianBlur") else {
        fatalError("Gaussian blur unavailable")
    }

    // 大尺度噪声（大陆板块）
    blur1.setValue(random, forKey: kCIInputImageKey)
    blur1.setValue(20.0, forKey: kCIInputRadiusKey)
    
    // 中大尺度噪声（山脉）
    blur2.setValue(random, forKey: kCIInputImageKey)
    blur2.setValue(10.0, forKey: kCIInputRadiusKey)
    
    // 中尺度噪声（丘陵）
    blur3.setValue(random, forKey: kCIInputImageKey)
    blur3.setValue(4.0, forKey: kCIInputRadiusKey)
    
    // 小尺度噪声（陨石坑细节）
    blur4.setValue(random, forKey: kCIInputImageKey)
    blur4.setValue(1.0, forKey: kCIInputRadiusKey)
    
    // 叠加多层噪声
    guard let add1 = CIFilter(name: "CIAdditionCompositing"),
          let add2 = CIFilter(name: "CIAdditionCompositing"),
          let add3 = CIFilter(name: "CIAdditionCompositing") else {
        fatalError("Addition compositing unavailable")
    }
    
    add1.setValue(blur1.outputImage, forKey: kCIInputImageKey)
    add1.setValue(blur2.outputImage, forKey: kCIInputBackgroundImageKey)
    
    add2.setValue(add1.outputImage, forKey: kCIInputImageKey)
    add2.setValue(blur3.outputImage, forKey: kCIInputBackgroundImageKey)
    
    add3.setValue(add2.outputImage, forKey: kCIInputImageKey)
    add3.setValue(blur4.outputImage, forKey: kCIInputBackgroundImageKey)
    
    // 适度增强对比度，保持平滑过渡
    guard let contrast = CIFilter(name: "CIColorControls") else {
        fatalError("ColorControls unavailable")
    }
    
    contrast.setValue(add3.outputImage, forKey: kCIInputImageKey)
    contrast.setValue(1.2, forKey: kCIInputContrastKey)  // 适度对比度，避免过度变形
    
    // 添加轻微模糊，让过渡更平滑
    guard let smoothBlur = CIFilter(name: "CIGaussianBlur") else {
        fatalError("Gaussian blur unavailable")
    }
    
    smoothBlur.setValue(contrast.outputImage, forKey: kCIInputImageKey)
    smoothBlur.setValue(0.5, forKey: kCIInputRadiusKey)

    return smoothBlur.outputImage!
}

// MARK: - Normal Map

private func generateNormalMap(from height: CIImage) -> UIImage {
    guard let filter = CIFilter(name: "CIHeightFieldFromMask") else {
        fatalError("HeightField filter unavailable")
    }

    filter.setValue(height, forKey: kCIInputImageKey)
    filter.setValue(8.0, forKey: "inputRadius")  // 适度半径，创造平滑的法线
    // inputScale 参数在某些 iOS 版本不支持，已移除

    guard
        let output = filter.outputImage,
        let cgImage = ciContext.createCGImage(output, from: output.extent)
    else {
        return UIImage()
    }

    return UIImage(cgImage: cgImage)
}

// MARK: - Roughness Map（结构派生）

private func generateRoughnessMap(from height: CIImage) -> UIImage {

    guard let edges = CIFilter(name: "CIEdges") else {
        fatalError("Edges filter unavailable")
    }

    edges.setValue(height, forKey: kCIInputImageKey)
    edges.setValue(5.0, forKey: kCIInputIntensityKey)

    guard let controls = CIFilter(name: "CIColorControls") else {
        fatalError("ColorControls unavailable")
    }

    controls.setValue(edges.outputImage, forKey: kCIInputImageKey)
    controls.setValue(2.0, forKey: kCIInputContrastKey)
    controls.setValue(0.0, forKey: kCIInputSaturationKey)
    controls.setValue(0.0, forKey: kCIInputBrightnessKey)

    guard
        let output = controls.outputImage,
        let cgImage = ciContext.createCGImage(output, from: output.extent)
    else {
        return UIImage()
    }

    return UIImage(cgImage: cgImage)
}

// MARK: - Color

private func randomBaseColor() -> UIColor {
    UIColor(
        hue: CGFloat.random(in: 0...1),
        saturation: CGFloat.random(in: 0.3...0.7),  // 随机饱和度
        brightness: CGFloat.random(in: 0.6...0.9),  // 随机亮度
        alpha: 1
    )
}
