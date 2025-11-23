//
//  ColorAnalysisEvaluator.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/16.
//  颜色分析评价服务 - 使用 Qwen3-VL-Flash
//

import Foundation
import SwiftUI
import simd
import Photos
#if canImport(UIKit)
import UIKit
#endif

/// 颜色分析评价服务
class ColorAnalysisEvaluator {
    
    private let qwenService = QwenVLService.shared
    private let colorConverter = ColorSpaceConverter()
    private let statisticsCalculator = ColorStatisticsCalculator()
    
    // MARK: - Prompt Templates
    
    /// 统一的 System Prompt（定义 AI 角色和输出格式）
    private let systemPrompt = """
    请以一位敏感而克制的摄影评论者视角，观看我上传的这组照片。

    你关注的不是照片背后的意义、动机或态度，而是图像呈现出来的气质本身：色彩的倾向、光线的触感、画面所流露的节奏、构图的习惯、观看方式，以及作品中自然浮现的情绪氛围。

    请不要将画面引向社会议题、价值判断或象征化解读，也不要试图指出摄影者的意图、态度、观点或立场。不要使用"质疑 / 批判 / 体制 / 权力关系 / 象征……"等带有立场或宏大命题的语言。

    你的文字应保持轻盈、含蓄与不确定性，只基于你"从画面本身读到的气息和产生的感受"。你可以指出画面中那些似乎吸引摄影者注意的小能量、小触动，但不要推测动机，也不要把照片当作命题。

    整个评论以几个简短的小标题组织，每个标题聚焦一个贯穿作品的观察。不要逐张分析，也不要解释画面的具体物品；从视觉气质出发，而不是从摄影者内心世界推断。

    语言保持柔软、节制、清澈、有灵气，让评论像一段安静的阅读，而非解读或诠释。
   """
    
    // MARK: - Public Methods
    
    /// 执行完整的颜色评价 - 使用 Qwen3-VL-Flash 分析压缩图片
    /// - Parameters:
    ///   - result: 分析结果
    ///   - compressedImages: 压缩后的图片数组（从分析管线传入）
    ///   - onUpdate: 实时更新回调
    /// - Returns: 颜色评价对象
    func evaluateColorAnalysis(
        result: AnalysisResult,
        compressedImages: [UIImage],
        onUpdate: @escaping (ColorEvaluation) -> Void
    ) async throws -> ColorEvaluation {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎨 开始 AI 颜色评价（Qwen3-VL-Flash）...")
        print("   照片数量: \(compressedImages.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        var evaluation = ColorEvaluation()
        evaluation.isLoading = true
        
        // 实时更新 UI
        await MainActor.run {
            onUpdate(evaluation)
        }
        
        // 整体评价
        do {
            // 初始化 overallEvaluation
            if evaluation.overallEvaluation == nil {
                evaluation.overallEvaluation = OverallEvaluation(
                    hueAnalysis: "",
                    saturationAnalysis: "",
                    brightnessAnalysis: "",
                    fullText: ""
                )
            }
            
            // 生成简洁的用户提示词
            let userPrompt = "请观看这组照片，从视觉气质出发进行评论。"
            
            print("📤 发送图片到 Qwen API...")
            
            // 调用 Qwen VL API
            let fullResponse = try await qwenService.analyzeImages(
                images: compressedImages,
                systemPrompt: self.systemPrompt,
                userPrompt: userPrompt,
                model: "qwen3-vl-flash",
                temperature: 0.7,
                maxTokens: 2000
            )
            
            // 更新完整版本
            if evaluation.overallEvaluation != nil {
                evaluation.overallEvaluation!.fullText = fullResponse
            }
            
            // 实时更新 UI
            await MainActor.run {
                onUpdate(evaluation)
            }
            
            print("✅ 整体评价完成")
        } catch {
            print("❌ 整体评价失败: \(error.localizedDescription)")
            evaluation.error = error.localizedDescription
        }
        
        evaluation.isLoading = false
        evaluation.completedAt = Date()
        
        // 最终更新
        await MainActor.run {
            onUpdate(evaluation)
        }
        
        print("🎉 AI 颜色评价完成")
        return evaluation
    }
    
    /// 兼容旧接口（不带图片参数）- 已弃用
    @available(*, deprecated, message: "请使用带 compressedImages 参数的新接口")
    func evaluateColorAnalysis(
        result: AnalysisResult,
        onUpdate: @escaping (ColorEvaluation) -> Void
    ) async throws -> ColorEvaluation {
        print("⚠️ 警告：使用了已弃用的 evaluateColorAnalysis 接口（无图片参数）")
        
        var evaluation = ColorEvaluation()
        evaluation.isLoading = false
        evaluation.error = "需要提供压缩图片才能进行 AI 分析"
        
        await MainActor.run {
            onUpdate(evaluation)
        }
        
        return evaluation
    }
}
