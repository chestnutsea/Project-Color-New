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
    private let settings = AnalysisSettings.shared
    
    // MARK: - Prompt Template
    
    /// System Prompt（中文版）
    private let systemPromptChinese = """
   
   我们现在就像一起坐下来，翻看我上传的照片。
   
   你不需要写一篇文章，只是轻轻说说你从画面里感到的最突出的东西。就像朋友之间慢慢交换一些观察，不总结，也不解释。 
   
   你可以关注但不必全部涉及也不必仅限于此：色彩大概偏向什么，光线摸上去是什么温度，画面的节奏是如何，空间、主体、拍摄视角、人物关系，似乎在讲述什么样的故事、呈现什么样的隐喻，有什么样的气质、情绪、氛围，等任何让你留意或触动的地方。
   
   你可以随口开启一个话头，但不要像正式段落那样整齐。句子有长有短也没关系，停顿一下、换个说法、轻轻带过去都可以。
   
   不要用"某张 / 这张"这样的词，把所有画面当作一个整体，找它们特质上的共性。 
   
   语言可以柔软、清澈、有灵气一些。尽量不要使用比喻句，不要用"像……"、"好比……"这样的句式。
   
   不要定义我，不要下结论。不要反驳和否定我。
   
   禁止使用"存在"这个词。不允许提及"存在"这个词！
   
   禁止使用否定句，当你有这种倾向时，使用正向陈述代替。
   
   不要想象画面中不存在的人事物。
   
   结尾不需要刻意升华，可以留白，或者一个淡淡的总结。
   
   """
    
    /// System Prompt（英文版）
    private let systemPromptEnglish = """
   
   We're sitting down together now, looking at the photos I've uploaded from a perspective of photographic documentation or creation.
   
   You don't need to write an essay, just gently share what you sense from the images. Like friends slowly exchanging observations—no summaries, no explanations.
   
   You may focus on, but don't need to cover all or limit yourself to: what the colors tend toward, what temperature the light feels like, how the rhythm of the frame moves, the space, subjects, shooting angles, relationships between people, what kind of story seems to be told, what metaphors emerge, what qualities, emotions, atmospheres appear, or anything else that catches your attention or touches you.
   
   You can casually start a thread of thought, but don't make it neat like formal paragraphs. Sentences can be long or short—it's fine to pause, rephrase, or gently move on.
   
   Don't use words like "a certain photo" or "this photo"—treat all images as a whole, finding their shared characteristics.
   
   Language can be soft, clear, and spirited. Try to avoid similes—don't use phrases like "like..." or "as if...".
   
   Don't define me, don't draw conclusions. Don't refute or negate me.
   
   Never use the word "exist" or "existence". This word is forbidden!
   
   Avoid negative sentences. When you have this tendency, use positive statements instead.
   
   Don't imagine people or things that don't appear in the images.
   
   The ending doesn't need deliberate elevation—you can leave space, or offer a gentle summary.
   
   """
    
    /// 根据当前语言选择 System Prompt
    private var systemPrompt: String {
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        
        // 如果是中文（简体或繁体），使用中文 prompt
        if currentLanguage.hasPrefix("zh") {
            return systemPromptChinese
        } else {
            // 其他语言使用英文 prompt
            return systemPromptEnglish
        }
    }
    
    // MARK: - Public Methods
    
    /// 执行完整的颜色评价 - 使用 Qwen3-VL-Flash 分析压缩图片
    /// - Parameters:
    ///   - result: 分析结果
    ///   - compressedImages: 压缩后的图片数组（从分析管线传入）
    ///   - userMessage: 用户输入的感受（可选，替换默认的 userPrompt）
    ///   - onUpdate: 实时更新回调
    /// - Returns: 颜色评价对象
    func evaluateColorAnalysis(
        result: AnalysisResult,
        compressedImages: [UIImage],
        userMessage: String? = nil,
        onUpdate: @escaping (ColorEvaluation) -> Void
    ) async throws -> ColorEvaluation {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎨 开始 AI 颜色评价（Qwen3-VL-Flash）...")
        print("   照片数量: \(compressedImages.count)")
        if let msg = userMessage, !msg.isEmpty {
            print("   用户感受: \(msg)")
        }
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
            
            // 生成用户提示词：如果用户输入了感受，使用用户的内容；否则使用默认提示词
            let userPrompt: String
            if let msg = userMessage, !msg.isEmpty {
                userPrompt = msg
            } else {
                // 根据当前语言选择默认提示词
                let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"
                userPrompt = currentLanguage.hasPrefix("zh") ? "请观看并评论。" : "Please view and comment."
            }
            
            print("📤 发送图片到 Qwen API（流式模式）...")
            
            // 用于节流 UI 更新
            var lastUpdateTime = Date()
            let updateInterval: TimeInterval = 0.05  // 每 50ms 更新一次 UI
            var isFirstToken = true
            
            // 使用 continuation 等待流式传输完成
            return await withCheckedContinuation { continuation in
                var hasResumed = false  // 防止重复 resume
                
                Task {
                    do {
                        // 使用流式 API（非阻塞）
                        try await qwenService.analyzeImagesStreaming(
                            images: compressedImages,
                            systemPrompt: systemPrompt,  // 使用计算属性获取当前视角的 prompt
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
                                    
                                    // 流式传输完成后才返回 evaluation（只 resume 一次）
                                    if !hasResumed {
                                        hasResumed = true
                                        continuation.resume(returning: evaluation)
                                    }
                                }
                            }
                        )
                        
                        print("✅ SSE 连接已建立，开始接收数据...")
                    } catch {
                        await MainActor.run {
                            print("❌ 整体评价失败: \(error.localizedDescription)")
                            evaluation.error = error.localizedDescription
                            evaluation.isLoading = false
                            evaluation.completedAt = Date()
                            onUpdate(evaluation)
                            
                            // 异常时也返回 evaluation（只 resume 一次）
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(returning: evaluation)
                            }
                        }
                    }
                }
            }
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
}
