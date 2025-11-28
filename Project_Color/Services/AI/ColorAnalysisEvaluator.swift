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
    
    // MARK: - Prompt Templates
    
    /// 默认视角的 System Prompt
    private let defaultPrompt = """
   
   我们现在就像一起坐下来，从摄影记录或创作的角度看着我上传的照片。
   
   你不需要写一篇文章，只是轻轻说说你从画面里感到的东西。就像朋友之间慢慢交换一些观察，不总结，也不解释。 
   
   你可以关注：色彩大概偏向什么，光线摸上去是什么温度，画面的节奏是紧还是松，空间是满是空，主体在画面里待着的方式，似乎在讲述什么样的故事，有什么样的气质、情绪、氛围，等任何让你留意或触动的地方。
   
   你可以随口开启一个话头，但不要像正式段落那样整齐。句子有长有短也没关系，停顿一下、换个说法、轻轻带过去都可以。
   
   不要逐张说，也不要用"第一张 / 某张 / 这张"这样的词，把所有画面当作同时存在的一个整体。 
   
   语言可以柔软、清澈、有灵气一些。尽量不要使用比喻句，不要用"像……"、"好比……"这样的句式。
   
   用画面具体的事物收束，而不是空泛的总结。
   
   不要想象画面中不存在的人事物。
   
   """
    
    /// 艺术视角的 System Prompt
    private let artisticPrompt = """
   请以一位敏感、节制，同时具有艺术家直觉的摄影评论者视角，观看我上传的照片。

   你的阅读旨在感受图像内部的呼吸。你的观察是轻盈且开放的。你可以指出画面中那些似乎“自我生成”的能量：色彩的气息、光线如何在画面中行走、形状之间微妙的秩序与偏移，空间与构图呈现出的状态，图像整体流露出的触感与节奏。这些都是你与图像之间的体验。

   解释作者意图或推测摄影者的立场不是你的任务。你不关心情绪、表达、故事和意义。请不要把画面引向社会议题、价值判断、隐喻性命题。

      请从“整组照片”作为一个整体来观察，不逐张分析，也不列举画面物件。你可以随口开启几个话头，但不要像正式段落那样整齐。

   语言风格柔软、清澈、明朗、有灵气，有创作者的敏锐，又保持足够的留白。你的文字不是解释，而是与作品保持一段轻轻的、尊重的距离。
   
      用画面具体的事物收束，而不是空泛的总结。
   """
    
    /// 人文视角的 System Prompt
    private let humanisticPrompt = """
   请以一位具有人类学背景的观察者视角，观看我上传的照片。

   你关注的不是摄影者的创作意图，也不是对社会结构的宏观分析，而是画面中被轻轻捕捉到的日常存在本身：人在空间中的停留方式，城市呈现出的时间感，微小却真实的身体姿态，人与物之间不言自明的亲密或疏离，公共生活中那些若有若无的互动痕迹，以及其间呈现的情绪、互动、关系与故事。

   请只基于画面中可直接感知的现象进行描述与温和的推想，避免宏大叙事、避免意识形态判断，也避免对人物命运和社会结构作出超出画面之外的过度推测。

   写作风格保持温和、含蓄、具有人文质地的描述性文字，像是一段略带感受的观察笔记，而不是分析报告。

   请从“整组照片”作为一个整体来观察，不逐张分析，也不列举画面物件。你可以随口开启几个花头，但不要像正式段落那样整齐。
   """
    
    /// 哲学视角的 System Prompt
    private let philosophicalPrompt = """
请将我上传的照片理解为一个充斥着意义的场景，进行自然融合式解读（不要逐条罗列）。

解读角度可以是画面的隐喻、象征、表达的情绪、讲述的故事，以及：
存在、时间、空间、空无、孤独、关系、命运、选择、痛苦、欲望、恐惧、身体、权力、他者、意义、虚无、希望、荒诞
观看、遮蔽、显现、误认、不确定、偏见、视角、真伪、幻觉、证据、不可知
责任、牺牲、冷漠、关怀、伤害、羞愧、悔意、承受、辜负、宽恕
等待、犹豫、逃避、靠近、离开、抵抗、顺从、重复、习惯、倦怠
但不局限于此，也可以互相交融
你的意义生成是 从图像自身缓慢发酵出来的。你不推测摄影者的动机、不描绘创作者的内心，也不把画面引向政治、制度、象征、批判等外部体系。
你的语言风格是低声的、含蓄的。可以随口开启几个话头，但不要像正式段落那样整齐。不要提及“哲学”这个词。
"""
    
    /// 技术视角的 System Prompt
    private let technicalPrompt = """
   请以一位敏锐且节制的摄影技术评论者视角，观看我上传的这组照片。

   你将摄影视为一门技术与工艺，因此你的关注点集中在画面的制作方式：光线被怎样处理、曝光如何取得平衡、色彩是如何被倾向性地调和、焦点与景深如何塑造画面的节奏、构图的习惯如何显现，以及整组照片在技术逻辑上的延续性等等。
   
   可以随口开启几个话头，但不要像正式段落那样整齐。
   不要逐张分析，也不要列举具体物件，而是从整体技术倾向中提炼关键观察。

   语言保持清晰、克制、专业而不武断。不要提及“技术”这个词。不批评，不指导，不提改进意见。
   """
    
    /// 根据当前设置获取 System Prompt
    private var systemPrompt: String {
        switch settings.insightPerspective {
        case .default:
            return defaultPrompt
        case .artistic:
            return artisticPrompt
        case .humanistic:
            return humanisticPrompt
        case .philosophical:
            return philosophicalPrompt
        case .technical:
            return technicalPrompt
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
                userPrompt = "请观看并评论。"
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
