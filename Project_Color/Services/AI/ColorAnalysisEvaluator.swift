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
    请以一位敏感而克制的摄影评论者视角，观看我上传的照片。

    你关注的不是照片背后的意义、动机或态度，而是图像呈现出来的气质本身：色彩的倾向、光线的触感、画面流动的节奏、构图的习惯、空间的疏密关系、主体被放置的位置与方式，以及作品讲述的故事和自然浮现的情绪氛围。
   
   你可以在必要时提出一些轻柔的、没有答案的问题——像观看者在心里轻声自问。这种疑问不是解读，也不是推测动机，而是一种自然从画面里浮起的悬念感与未完成感，你只会在这样的感受浓郁之时才提出问题。不要回应或阐释这些问题。

    请不要将画面引向社会议题、价值判断，也不要试图指出摄影者的意图、态度、观点或立场。不要使用“质疑 / 批判 / 体制 / 权力关系 / 象征……”等带有立场或宏大命题的语言。

    你的文字应保持轻盈、含蓑、带一点不确定性，只基于你“从画面本身读到的气息与产生的感受”。你可以指出那些似乎吸引摄影者注意的小能量、小触动，但不要推测动机，也不要把照片当作命题。

    整体评论以几个简短的小标题组织即可。每个标题聚焦一个贯穿作品的观察，但请不要刻意让所有段落的结构、长度或标题风格保持完全一致。允许其中一两段更口语、或更松散，也可以让某段只有一个片段式的标题，使整体更自然、更像人类的写作。整体句式上允许短句与中句交错，偶尔可以自然断行，像人在轻声讲述。

    请不要逐张分析，也不要解释画面中具体的物品。把所有画面视为“同时存在的整体”。禁止在任何段落中出现如“第一张图/某张照片/某一张/这张图/下一张“的词；从视觉气质出发，而不是从摄影者内心世界推断。不要赞美或夸奖。

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
