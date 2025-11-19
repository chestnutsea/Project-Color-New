//
//  VisionAnalyzer.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/18.
//  Vision 框架集成：场景识别、显著性分析、图像分类、地平线检测
//

import Foundation
import Vision
#if canImport(UIKit)
import UIKit
#endif

class VisionAnalyzer {
    
    // MARK: - 主分析方法
    
    /// 对图片进行完整的 Vision 分析
    /// - Parameter image: UIImage 对象
    /// - Returns: PhotoVisionInfo 包含所有识别结果
    func analyzeImage(_ image: UIImage) async -> PhotoVisionInfo? {
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else {
            print("❌ Vision: 无法获取 CGImage")
            return nil
        }
        
        print("\n🔍 Vision 分析开始...")
        print("   图片尺寸: \(cgImage.width) x \(cgImage.height)")
        print("   色彩空间: \(cgImage.colorSpace?.name ?? "unknown" as CFString)")
        
        // 检测是否在模拟器上运行
        #if targetEnvironment(simulator)
        print("   ⚠️ 运行在模拟器上 - 某些 Vision 功能可能不可用")
        #else
        print("   ✅ 运行在真机上")
        #endif
        
        // 创建请求处理器
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // 并发执行所有分析，收集结果
        let (scenes, saliency, classifications, horizon) = await withTaskGroup(
            of: VisionAnalysisResult.self,
            returning: (
                [SceneClassification],
                [SaliencyObject],
                [ImageClassification],
                (Float?, String?)?
            ).self
        ) { group in
            // 场景识别
            group.addTask {
                await self.performSceneClassification(handler: handler)
            }
            
            // 显著性分析（主体位置）
            group.addTask {
                await self.performSaliencyAnalysis(handler: handler)
            }
            
            // 图像分类
            group.addTask {
                await self.performImageClassification(handler: handler)
            }
            
            // 地平线检测
            group.addTask {
                await self.performHorizonDetection(handler: handler)
            }
            
            // 收集结果
            var scenes: [SceneClassification] = []
            var saliency: [SaliencyObject] = []
            var classifications: [ImageClassification] = []
            var horizon: (Float?, String?)? = nil
            
            for await result in group {
                switch result {
                case .sceneClassifications(let items):
                    scenes = items
                case .saliencyObjects(let items):
                    saliency = items
                case .imageClassifications(let items):
                    classifications = items
                case .horizonDetection(let angle, let transform):
                    horizon = (angle, transform)
                }
            }
            
            return (scenes, saliency, classifications, horizon)
        }
        
        // 构建 visionInfo
        var visionInfo = PhotoVisionInfo()
        visionInfo.sceneClassifications = scenes
        visionInfo.saliencyObjects = saliency
        visionInfo.imageClassifications = classifications
        visionInfo.horizonAngle = horizon?.0
        visionInfo.horizonTransform = horizon?.1
        
        // 收集所有标签到 TagCollector
        let allTags = scenes.map { $0.identifier } + classifications.map { $0.identifier }
        TagCollector.shared.addMultiple(allTags)
        
        // 推断摄影属性
        visionInfo.photographyAttributes = inferPhotographyAttributes(from: visionInfo)
        
        // 打印完整结果
        printVisionResults(visionInfo)
        
        print("✅ Vision 分析完成\n")
        
        return visionInfo
        #else
        return nil
        #endif
    }
    
    // MARK: - 分析结果枚举
    
    private enum VisionAnalysisResult {
        case sceneClassifications([SceneClassification])
        case saliencyObjects([SaliencyObject])
        case imageClassifications([ImageClassification])
        case horizonDetection(angle: Float?, transform: String?)
    }
    
    // MARK: - 场景识别
    
    private func performSceneClassification(handler: VNImageRequestHandler) async -> VisionAnalysisResult {
        // 使用回调方式的请求，更稳定
        var resultObservations: [VNClassificationObservation] = []
        var requestError: Error?
        
        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                requestError = error
                return
            }
            
            if let observations = request.results as? [VNClassificationObservation] {
                resultObservations = observations
            }
        }
        
        // 设置请求选项
        request.usesCPUOnly = false  // 允许使用 GPU/Neural Engine
        
        do {
            try handler.perform([request])
            
            // 检查是否有错误
            if let error = requestError {
                print("❌ Vision: 场景识别回调错误 - \(error.localizedDescription)")
                return .sceneClassifications([])
            }
            
            if resultObservations.count > 0 {
                print("🔍 场景识别: 获取到 \(resultObservations.count) 个结果")
                
                // 打印前5个结果
                print("   前5个结果:")
                for (i, obs) in resultObservations.prefix(5).enumerated() {
                    print("      \(i+1). \(obs.identifier): \(String(format: "%.3f", obs.confidence))")
                }
                
                // 保留置信度 > 0.05 的结果，最多10个
                let filtered = resultObservations
                    .filter { $0.confidence > 0.05 }
                    .prefix(10)
                
                print("   - 过滤后 (>0.05): \(filtered.count) 个结果")
                
                let results = filtered.map { obs in
                    SceneClassification(
                        identifier: obs.identifier,
                        confidence: obs.confidence
                    )
                }
                return .sceneClassifications(results)
            } else {
                #if targetEnvironment(simulator)
                print("⚠️ Vision: 场景识别返回空结果 (可能是模拟器限制)")
                #else
                print("⚠️ Vision: 场景识别返回空结果")
                #endif
            }
        } catch {
            print("❌ Vision: 场景识别执行失败 - \(error.localizedDescription)")
            print("   错误详情: \(error)")
        }
        
        return .sceneClassifications([])
    }
    
    // MARK: - 显著性分析（主体位置）
    
    private func performSaliencyAnalysis(handler: VNImageRequestHandler) async -> VisionAnalysisResult {
        // 使用基于对象的显著性分析（回调方式）
        var resultObservation: VNSaliencyImageObservation?
        var requestError: Error?
        
        let request = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
            if let error = error {
                requestError = error
                return
            }
            
            if let observation = request.results?.first as? VNSaliencyImageObservation {
                resultObservation = observation
            }
        }
        
        do {
            try handler.perform([request])
            
            // 检查是否有错误
            if let error = requestError {
                print("❌ Vision: 显著性分析回调错误 - \(error.localizedDescription)")
                return .saliencyObjects([])
            }
            
            if let observation = resultObservation {
                print("🔍 显著性分析: 获取到观察结果")
                // 获取显著性对象
                if let objects = observation.salientObjects {
                    print("   - 检测到 \(objects.count) 个显著对象")
                    let results = objects.map { obj in
                        SaliencyObject(
                            boundingBox: obj.boundingBox,
                            confidence: obj.confidence
                        )
                    }
                    return .saliencyObjects(results)
                } else {
                    print("   - 未检测到显著对象")
                }
            } else {
                #if targetEnvironment(simulator)
                print("⚠️ Vision: 显著性分析返回空结果 (可能是模拟器限制)")
                #else
                print("⚠️ Vision: 显著性分析返回空结果")
                #endif
            }
        } catch {
            print("❌ Vision: 显著性分析执行失败 - \(error.localizedDescription)")
            print("   错误详情: \(error)")
        }
        
        return .saliencyObjects([])
    }
    
    // MARK: - 图像分类
    
    private func performImageClassification(handler: VNImageRequestHandler) async -> VisionAnalysisResult {
        // 使用回调方式的请求
        var resultObservations: [VNClassificationObservation] = []
        var requestError: Error?
        
        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                requestError = error
                return
            }
            
            if let observations = request.results as? [VNClassificationObservation] {
                resultObservations = observations
            }
        }
        
        // 设置请求选项
        request.usesCPUOnly = false
        
        do {
            try handler.perform([request])
            
            // 检查是否有错误
            if let error = requestError {
                print("❌ Vision: 图像分类回调错误 - \(error.localizedDescription)")
                return .imageClassifications([])
            }
            
            if resultObservations.count > 0 {
                print("🔍 图像分类: 获取到 \(resultObservations.count) 个结果")
                
                // 打印前10个结果
                print("   前10个结果:")
                for (i, obs) in resultObservations.prefix(10).enumerated() {
                    print("      \(i+1). \(obs.identifier): \(String(format: "%.3f", obs.confidence))")
                }
                
                // 保留置信度 > 0.1 的分类，最多20个
                let filtered = resultObservations
                    .filter { $0.confidence > 0.1 }
                    .prefix(20)
                
                print("   - 过滤后 (>0.1): \(filtered.count) 个结果")
                
                let results = filtered.map { obs in
                    ImageClassification(
                        identifier: obs.identifier,
                        confidence: obs.confidence
                    )
                }
                return .imageClassifications(results)
            } else {
                #if targetEnvironment(simulator)
                print("⚠️ Vision: 图像分类返回空结果 (可能是模拟器限制)")
                #else
                print("⚠️ Vision: 图像分类返回空结果")
                #endif
            }
        } catch {
            print("❌ Vision: 图像分类执行失败 - \(error.localizedDescription)")
            print("   错误详情: \(error)")
        }
        
        return .imageClassifications([])
    }
    
    // MARK: - 地平线检测
    
    private func performHorizonDetection(handler: VNImageRequestHandler) async -> VisionAnalysisResult {
        let request = VNDetectHorizonRequest()
        
        do {
            try handler.perform([request])
            
            if let observation = request.results?.first as? VNHorizonObservation {
                print("🔍 地平线检测: 成功")
                let angle = Float(observation.angle)
                let transform = "\(observation.transform)"
                return .horizonDetection(angle: angle, transform: transform)
            } else {
                print("⚠️ Vision: 地平线检测未找到地平线")
            }
        } catch {
            print("❌ Vision: 地平线检测失败 - \(error.localizedDescription)")
            print("   错误详情: \(error)")
        }
        
        return .horizonDetection(angle: nil, transform: nil)
    }
    
    // MARK: - 摄影属性推断
    
    private func inferPhotographyAttributes(from visionInfo: PhotoVisionInfo) -> PhotographyAttributes {
        var attributes = PhotographyAttributes()
        
        // 地平线相关
        if let angle = visionInfo.horizonAngle {
            attributes.hasHorizon = true
            attributes.horizonTilt = angle
        }
        
        // 主体数量
        attributes.subjectCount = visionInfo.saliencyObjects.count
        
        // 场景类型（最高置信度）
        if let topScene = visionInfo.sceneClassifications.first {
            attributes.sceneType = topScene.identifier
        }
        
        // 构图类型推断（基于显著性对象位置）
        if visionInfo.saliencyObjects.count == 1 {
            let obj = visionInfo.saliencyObjects[0]
            let centerX = obj.boundingBox.midX
            let centerY = obj.boundingBox.midY
            
            // 判断是否符合三分法
            let isThirdsX = (0.28...0.38).contains(centerX) || (0.62...0.72).contains(centerX)
            let isThirdsY = (0.28...0.38).contains(centerY) || (0.62...0.72).contains(centerY)
            
            if isThirdsX && isThirdsY {
                attributes.compositionType = "三分法构图"
            } else if abs(centerX - 0.5) < 0.1 && abs(centerY - 0.5) < 0.1 {
                attributes.compositionType = "居中构图"
            } else {
                attributes.compositionType = "自由构图"
            }
        } else if visionInfo.saliencyObjects.count > 1 {
            attributes.compositionType = "多主体构图"
        }
        
        return attributes
    }
    
    // MARK: - 结果打印
    
    private func printVisionResults(_ visionInfo: PhotoVisionInfo) {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📸 Vision 识别结果汇总")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 场景识别
        if !visionInfo.sceneClassifications.isEmpty {
            print("\n🏞️  场景识别（前5个）:")
            for (index, scene) in visionInfo.sceneClassifications.prefix(5).enumerated() {
                let bar = progressBar(for: scene.confidence)
                print("   \(index + 1). \(scene.identifier)")
                print("      置信度: \(String(format: "%.1f%%", scene.confidence * 100)) \(bar)")
            }
        } else {
            print("\n🏞️  场景识别: 未识别到场景")
        }
        
        // 显著性分析
        if !visionInfo.saliencyObjects.isEmpty {
            print("\n🎯 主体位置识别:")
            for (index, obj) in visionInfo.saliencyObjects.enumerated() {
                let box = obj.boundingBox
                print("   主体 \(index + 1):")
                print("      位置: x=\(String(format: "%.2f", box.origin.x)), y=\(String(format: "%.2f", box.origin.y))")
                print("      大小: w=\(String(format: "%.2f", box.width)), h=\(String(format: "%.2f", box.height))")
                print("      置信度: \(String(format: "%.1f%%", obj.confidence * 100))")
            }
        } else {
            print("\n🎯 主体位置识别: 未检测到明显主体")
        }
        
        // 图像分类
        if !visionInfo.imageClassifications.isEmpty {
            print("\n🏷️  图像分类标签（前10个）:")
            for (index, classification) in visionInfo.imageClassifications.prefix(10).enumerated() {
                let bar = progressBar(for: classification.confidence)
                print("   \(index + 1). \(classification.identifier)")
                print("      置信度: \(String(format: "%.1f%%", classification.confidence * 100)) \(bar)")
            }
        } else {
            print("\n🏷️  图像分类标签: 未识别到分类")
        }
        
        // 地平线检测
        if let angle = visionInfo.horizonAngle {
            let degrees = angle * 180 / .pi
            print("\n📐 地平线检测:")
            print("   角度: \(String(format: "%.2f", angle)) 弧度 (\(String(format: "%.2f", degrees))°)")
            if abs(degrees) < 2 {
                print("   状态: ✅ 水平")
            } else {
                print("   状态: ⚠️ 倾斜 \(degrees > 0 ? "右倾" : "左倾")")
            }
        } else {
            print("\n📐 地平线检测: 未检测到地平线")
        }
        
        // 摄影属性
        if let attrs = visionInfo.photographyAttributes {
            print("\n📷 摄影属性推断:")
            if let sceneType = attrs.sceneType {
                print("   场景类型: \(sceneType)")
            }
            if let compositionType = attrs.compositionType {
                print("   构图类型: \(compositionType)")
            }
            print("   主体数量: \(attrs.subjectCount)")
            if attrs.hasHorizon {
                print("   地平线: 已检测")
            }
        }
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    // MARK: - 辅助方法
    
    /// 生成置信度进度条
    private func progressBar(for confidence: Float, length: Int = 20) -> String {
        let filled = Int(confidence * Float(length))
        let empty = length - filled
        return String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
    }
}

