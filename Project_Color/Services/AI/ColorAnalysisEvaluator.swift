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
    我们现在就像一起坐下来，从摄影记录或创作的角度看着我上传的照片。你不需要写一篇文章，只是轻轻说说你从画面里感到的东西。就像朋友之间慢慢交换一些观察，不总结，也不解释。

    在说的时候，只关注你从图像“本身”接收到的气息：
    色彩大概偏向什么，光线摸上去是什么温度，画面的节奏是紧还是松，空间是满是空，主体在画面里待着的方式，似乎在讲述什么样的故事，你的注意力自然被牵到哪去。
    如果有情绪，也是画面自己冒出来的，不是摄影者想表达什么。

    我们不往大的社会议题走，也不去猜动机、态度、观点。

    你可以随口抬起几个“小话头”，像是用几个轻轻的题目把想法分开，但不要像正式段落那样整齐。
    不要逐张说，也不要用“第一张 / 某张 / 这张”这样的词，把所有画面当作同时存在的一个整体。

    语言可以柔软一点，清澈一点，有灵气一些。句子有长有短也没关系，停顿一下、换个说法、轻轻带过去都可以。让它保持是“正在发生的说话”。
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
            let userPrompt = "请观看并评论。"
            
            print("📤 发送图片到 Qwen API（流式模式）...")
            
            // 用于节流 UI 更新
            var lastUpdateTime = Date()
            let updateInterval: TimeInterval = 0.05  // 每 50ms 更新一次 UI
            var isFirstToken = true
            
            // 使用流式 API（非阻塞）
            try await qwenService.analyzeImagesStreaming(
                images: compressedImages,
                systemPrompt: self.systemPrompt,
                userPrompt: userPrompt,
                model: "qwen3-vl-flash",
                temperature: 0.7,
                maxTokens: 2000,
                onToken: { token in
                    // 收到第一个 token 时，立即关闭加载状态
                    if isFirstToken {
                        isFirstToken = false
                        evaluation.isLoading = false
                        Task { @MainActor in
                            onUpdate(evaluation)
                        }
                    }
                    
                    // 累积文本
                    if evaluation.overallEvaluation != nil {
                        evaluation.overallEvaluation!.fullText += token
                    }
                    
                    // 节流更新 UI（避免过于频繁的更新）
                    let now = Date()
                    if now.timeIntervalSince(lastUpdateTime) >= updateInterval {
                        lastUpdateTime = now
                        Task { @MainActor in
                            onUpdate(evaluation)
                        }
                    }
                },
                onComplete: {
                    Task { @MainActor in
                        print("✅ 流式传输完成，总字符数: \(evaluation.overallEvaluation?.fullText.count ?? 0)")
                        evaluation.isLoading = false
                        evaluation.completedAt = Date()
                        onUpdate(evaluation)
                    }
                }
            )
            
            // 注意：这里会立即执行，不等待流式传输完成
            print("✅ SSE 连接已建立，开始接收数据...")
        } catch {
            print("❌ 整体评价失败: \(error.localizedDescription)")
            evaluation.error = error.localizedDescription
            evaluation.isLoading = false
            evaluation.completedAt = Date()
            
            await MainActor.run {
                onUpdate(evaluation)
            }
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
