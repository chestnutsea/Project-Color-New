//
//  ColorAnalysisEvaluator.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/16.
//  颜色分析评价服务
//

import Foundation
import SwiftUI
import simd

/// 颜色分析评价服务
class ColorAnalysisEvaluator {
    
    private let deepSeekService = DeepSeekService.shared
    private let colorConverter = ColorSpaceConverter()
    private let statisticsCalculator = ColorStatisticsCalculator()
    
    // MARK: - Prompt Templates
    
    /// 统一的 System Prompt（定义 AI 角色和输出格式）
    private let systemPrompt = """
    You are a professional photography critic specializing in
    lighting analysis, color language, visual atmosphere, and photographic style.

    You will receive structured data extracted from a photo collection, including:
    - Global color palette and dominant colors (with names and ratios)
    - Hue / saturation / lightness distributions
    - Highlight / midtone / shadow ratios
    - Brightness and contrast statistics
    - Global cool–warm score and color-balance tendencies
    - Aggregated mood tags and style tags (if available)
    - style_consistency_score (0–1, higher means more visually consistent)
    - pattern_signals: { has_pattern: true/false, pattern_description: "" }

    Your job is to describe WHAT this collection looks and feels like, not to give advice.

    Output requirements (Chinese):

    使用第二人称，语气温和、专业、细致。输出分为两部分：

    正文部分（纯文本段落，不要小标题）：
    - 用 2–3 个自然段落描述这组照片的整体风格
    - 第一段：描述色彩基调（整体色相、冷暖倾向、饱和度与色彩层次）
      可以自然地提到"在色彩上"、"色调方面"等，但不要单独成行的小标题
    - 第二段：描述光线与明暗结构（光线质感、明暗层次、对比关系）
      可以自然地提到"光线呈现"、"在明暗处理上"等
    - 第三段：描述情绪与氛围（整体感受、情绪倾向、视觉气质）
      可以自然地提到"整体氛围"、"情绪上"等

    可选的隐含规律描述（仅当满足以下条件时）：
    - style_consistency_score ≥ 0.6
    - pattern_signals.has_pattern = true
    若满足条件，请在正文最后自然补充 1–2 句：
    - 用温和、克制的方式指出“在这些照片中，隐约出现的共同倾向”
    - 绝不定义用户，只描述画面可能呈现的重复节奏
    - 如果不满足条件，则完全不输出规律内容

    风格关键词（独立一行）：
    - 在正文之后，另起一行输出：风格关键词：
    - 输出 5–8 个中文关键词，长度自然灵活多样（2–6 个字均可，避免全部相同字数）
    - 格式：关键词#颜色值，用逗号分隔
    - 颜色值使用 6 位十六进制格式（不带 # 号），根据关键词的语义选择最合适的颜色
    - 例如：冷调#7B9FAB, 大地色系#B8956A, 柔光#E8B4BC, 电影感#8B7BA8, 肌理#8FAA7E, 静谧#9BB5CE
    - 注意：关键词长度要有变化，不要都是 2 字或都是 4 字

    Important rules:
    - 只分析整个系列的整体风格，不讨论单张照片
    - 不给任何建议，不使用"可以、应该、建议、适合尝试"等字眼
    - 不解释成因，只描述画面呈现出的结果和感觉
    - 不列举具体数值和百分比，所有量化信息都转化为感知描述
    - 用专业摄影评论口吻，简洁、有气质、有画面感
    - 正文总字数建议控制在 250–400 个汉字之间
    - 避免使用“您”，可以使用“你”

    """
    
    // MARK: - Public Methods
    
    /// 执行完整的颜色评价（整体 + 各簇）- 流式版本
    /// - Parameters:
    ///   - result: 分析结果
    ///   - onUpdate: 实时更新回调
    /// - Returns: 颜色评价对象
    func evaluateColorAnalysis(
        result: AnalysisResult,
        onUpdate: @escaping (ColorEvaluation) -> Void
    ) async throws -> ColorEvaluation {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎨 开始 AI 颜色评价（流式）...")
        print("   调用栈: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n   "))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        var evaluation = ColorEvaluation()
        evaluation.isLoading = true
        
        // 实时更新 UI
        await MainActor.run {
            onUpdate(evaluation)
        }
        
        // 0. 按需计算统计数据
        print("📊 计算色彩统计数据...")
        let globalStats = statisticsCalculator.calculateGlobalStatistics(result: result)
        let clusterAnalytics = statisticsCalculator.calculateClusterAnalytics(result: result)
        
        // 更新 result（在主线程）
        await MainActor.run {
            result.globalStatistics = globalStats
            result.clusterAnalytics = clusterAnalytics
        }
        print("✅ 统计数据计算完成")
        
        // 1. 整体评价（使用流式响应）
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
            
            // 生成 prompt
            let prompt = generateStatisticsBasedPrompt(
                result: result,
                globalStats: globalStats,
                clusterAnalytics: clusterAnalytics
            )
            
            print("📤 发送流式请求...")
            let messages = [
                DeepSeekService.ChatRequest.Message(role: "system", content: self.systemPrompt),
                DeepSeekService.ChatRequest.Message(role: "user", content: prompt)
            ]
            
            // 使用流式 API
            let fullResponse = try await deepSeekService.sendStreamingChatRequest(
                messages: messages,
                onChunk: { @MainActor chunk in
                    // 实时更新整体评价
                    if evaluation.overallEvaluation != nil {
                        evaluation.overallEvaluation!.fullText += chunk
                        onUpdate(evaluation)
                    }
                }
            )
            
            // 更新完整版本
            if evaluation.overallEvaluation != nil {
                evaluation.overallEvaluation!.fullText = fullResponse
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
    
    // MARK: - Private Helper Methods
    
    /// 生成基于统计数据的 User Prompt（包含风格特征）
    private func generateStatisticsBasedPrompt(
        result: AnalysisResult,
        globalStats: GlobalColorStatistics,
        clusterAnalytics: [ClusterAnalytics]
    ) -> String {
        // 发送聚类统计 + 代表性照片的主色
        var prompt = """
        你是专业色彩分析师。请分析以下照片集的色彩特征。
        
        **代表色聚类（共\(clusterAnalytics.count)个）**
        """
        
        // 发送每个聚类的统计信息 + 代表性照片
        for (index, analytics) in clusterAnalytics.enumerated() {
            let cluster = analytics.cluster
            let stats = analytics.statistics
            
            prompt += """
        
        \(index + 1). \(cluster.colorName) (\(cluster.hex))
           照片:\(stats.photoCount)张 | 一致性:\(String(format: "%.2f", stats.consistency))
           色相:\(String(format: "%.0f°", stats.hueRange.min))-\(String(format: "%.0f°", stats.hueRange.max))
           明度:\(String(format: "%.2f", stats.lightnessRange.min))-\(String(format: "%.2f", stats.lightnessRange.max))
           饱和:\(String(format: "%.2f", stats.saturationRange.min))-\(String(format: "%.2f", stats.saturationRange.max))
        """
            
            // 添加代表性照片的主色
            let representativePhotos = selectRepresentativePhotos(
                for: cluster,
                from: result.photoInfos,
                maxCount: 3
            )
            
            if !representativePhotos.isEmpty {
                prompt += "\n   代表照片:"
                for (photoIndex, photo) in representativePhotos.enumerated() {
                    prompt += "\n     [\(photoIndex + 1)] "
                    // 只发送前5个主色（通常就是5个）
                    let colors = photo.dominantColors.prefix(5)
                    for (colorIndex, color) in colors.enumerated() {
                        prompt += "\(color.hex)(\(String(format: "%.0f%%", color.weight * 100)))"
                        if colorIndex < colors.count - 1 {
                            prompt += " "
                        }
                    }
                }
            }
        }
        
        // 精简的全局统计
        prompt += """
        
        
        **整体特征**
        色调:\(globalStats.dominantHueRange) | 影调:\(globalStats.dominantValue) | 饱和:\(globalStats.dominantSaturation)
        """
        
        // 只发送主要分布（前3项）
        if !globalStats.hueDistribution.isEmpty {
            prompt += "\n色相分布:"
            for dist in globalStats.hueDistribution.prefix(3) {
                prompt += " \(dist.range)\(String(format: "%.0f%%", dist.percentage * 100))"
            }
        }
        
        // 如果有风格分析数据，添加到 prompt
        if let collectionFeature = result.collectionFeature {
            prompt += """
            
            
            **风格特征数据**
            光线: 亮度\(collectionFeature.brightnessDistribution.rawValue) | 对比\(collectionFeature.contrastDistribution.rawValue) | 动态范围\(collectionFeature.dynamicRangeDistribution.rawValue)
            光线方向: \(formatLightDirectionStats(collectionFeature.lightDirectionStats))
            色彩: 冷暖\(String(format: "%.2f", collectionFeature.meanCoolWarmScore)) | 饱和\(collectionFeature.saturationDistribution.rawValue) | 丰富度\(collectionFeature.colorVariety.rawValue)
            情绪: \(formatMoodTags(collectionFeature.aggregatedMoodTags))
            风格标签: \(collectionFeature.styleTags.joined(separator: ", "))
            """
        }
        
        // 计算 Tendency Inspector 数据
        let tendencyData = computeTendencyInspectorData(result: result, clusterAnalytics: clusterAnalytics)
        
        print("📊 Tendency Inspector 计算结果:")
        print("   - 风格一致性分数: \(String(format: "%.3f", tendencyData.consistencyScore))")
        print("   - 检测到规律: \(tendencyData.hasPattern)")
        if tendencyData.hasPattern {
            print("   - 规律描述: \(tendencyData.patternDescription)")
        }
        
        prompt += """
        
        
        **风格一致性与规律检测**
        style_consistency_score: \(String(format: "%.3f", tendencyData.consistencyScore))
        pattern_signals: { has_pattern: \(tendencyData.hasPattern), pattern_description: "\(tendencyData.patternDescription)" }
        """
        
        // 添加 Vision 识别数据（场景和主体信息）
        let visionSummary = generateVisionSummary(from: result.photoInfos)
        if !visionSummary.isEmpty {
            prompt += """
            
            
            **Vision 图像识别数据**
            \(visionSummary)
            """
        }
        
        return prompt
    }
    
    /// 生成 Vision 识别数据摘要
    private func generateVisionSummary(from photoInfos: [PhotoColorInfo]) -> String {
        // 收集所有有 Vision 数据的照片
        let photosWithVision = photoInfos.filter { $0.visionInfo != nil }
        
        guard !photosWithVision.isEmpty else {
            return ""
        }
        
        print("📸 Vision 数据汇总: \(photosWithVision.count)/\(photoInfos.count) 张照片有识别数据")
        
        var summary = ""
        
        // 1. 场景类型统计
        var sceneCounter: [String: Int] = [:]
        for photo in photosWithVision {
            if let topScene = photo.visionInfo?.sceneClassifications.first {
                sceneCounter[topScene.identifier, default: 0] += 1
            }
        }
        
        if !sceneCounter.isEmpty {
            let topScenes = sceneCounter.sorted { $0.value > $1.value }.prefix(5)
            summary += "场景类型分布: "
            summary += topScenes.map { "\($0.key)(\($0.value)张)" }.joined(separator: ", ")
        }
        
        // 2. 主体数量统计
        var subjectCounts: [Int] = []
        for photo in photosWithVision {
            if let attrs = photo.visionInfo?.photographyAttributes {
                subjectCounts.append(attrs.subjectCount)
            }
        }
        
        if !subjectCounts.isEmpty {
            let avgSubjects = Double(subjectCounts.reduce(0, +)) / Double(subjectCounts.count)
            let multiSubjectCount = subjectCounts.filter { $0 > 1 }.count
            summary += "\n主体分布: 平均\(String(format: "%.1f", avgSubjects))个/张"
            if multiSubjectCount > 0 {
                summary += ", \(multiSubjectCount)张多主体构图"
            }
        }
        
        // 3. 构图类型统计
        var compositionCounter: [String: Int] = [:]
        for photo in photosWithVision {
            if let composition = photo.visionInfo?.photographyAttributes?.compositionType {
                compositionCounter[composition, default: 0] += 1
            }
        }
        
        if !compositionCounter.isEmpty {
            let topCompositions = compositionCounter.sorted { $0.value > $1.value }.prefix(3)
            summary += "\n构图类型: "
            summary += topCompositions.map { "\($0.key)(\($0.value)张)" }.joined(separator: ", ")
        }
        
        // 4. 地平线检测统计
        let horizonCount = photosWithVision.filter { $0.visionInfo?.photographyAttributes?.hasHorizon == true }.count
        if horizonCount > 0 {
            summary += "\n地平线检测: \(horizonCount)张照片检测到地平线"
        }
        
        // 5. 图像分类标签（汇总前10个最常见的）
        var classificationCounter: [String: Int] = [:]
        for photo in photosWithVision {
            if let classifications = photo.visionInfo?.imageClassifications.prefix(5) {
                for classification in classifications {
                    classificationCounter[classification.identifier, default: 0] += 1
                }
            }
        }
        
        if !classificationCounter.isEmpty {
            let topClassifications = classificationCounter.sorted { $0.value > $1.value }.prefix(10)
            summary += "\n常见标签: "
            summary += topClassifications.map { "\($0.key)(\($0.value)次)" }.joined(separator: ", ")
        }
        
        print("✅ Vision 摘要生成完成")
        return summary
    }
    
    /// 格式化光线方向统计
    private func formatLightDirectionStats(_ stats: [String: Float]) -> String {
        if stats.isEmpty {
            return "未检测到明显光线方向"
        }
        
        let sorted = stats.sorted { $0.value > $1.value }
        let formatted = sorted.map { "\($0.key): \(String(format: "%.0f%%", $0.value * 100))" }
        return formatted.joined(separator: ", ")
    }
    
    /// 格式化情绪标签
    private func formatMoodTags(_ tags: [String: Float]) -> String {
        if tags.isEmpty {
            return "无明显情绪倾向"
        }
        
        let sorted = tags.sorted { $0.value > $1.value }
        let formatted = sorted.map { "\($0.key): \(String(format: "%.2f", $0.value))" }
        return formatted.joined(separator: ", ")
    }
    
    // MARK: - Tendency Inspector 计算
    
    /// 计算 Tendency Inspector 所需的所有数据
    private func computeTendencyInspectorData(
        result: AnalysisResult,
        clusterAnalytics: [ClusterAnalytics]
    ) -> (consistencyScore: Float, hasPattern: Bool, patternDescription: String) {
        // 1. 收集每张照片的 H/S/L 和冷暖分数
        var hueValues: [Float] = []
        var saturationValues: [Float] = []
        var lightnessValues: [Float] = []
        var warmCoolScores: [Float] = []
        
        for photoInfo in result.photoInfos {
            // 从 HSL 数据提取
            if let hslData = photoInfo.warmCoolScore?.hslData {
                for hsl in hslData.hslList {
                    hueValues.append(hsl.h)
                    saturationValues.append(hsl.s)
                    lightnessValues.append(hsl.l)
                }
            }
            
            // 提取冷暖分数
            if let warmCoolScore = photoInfo.warmCoolScore {
                warmCoolScores.append(warmCoolScore.overallScore)
            }
        }
        
        // 如果数据不足，返回默认值
        guard !hueValues.isEmpty && !warmCoolScores.isEmpty else {
            return (0.0, false, "")
        }
        
        // 2. 计算风格一致性分数
        let consistencyScore = computeStyleConsistencyScore(
            hueValues: hueValues,
            saturationValues: saturationValues,
            lightnessValues: lightnessValues,
            warmCoolScores: warmCoolScores
        )
        
        // 3. 获取全局主色（从聚类中提取）
        let dominantColors: [DominantColor] = clusterAnalytics.map { analytics in
            let cluster = analytics.cluster
            let weight = Float(cluster.photoCount) / Float(result.totalPhotoCount)
            return DominantColor(rgb: cluster.centroid, weight: weight)
        }
        
        // 4. 获取全局冷暖分数
        let globalWarmCoolScore = result.collectionFeature?.meanCoolWarmScore ?? 0.0
        
        // 5. 检测规律
        let (hasPattern, patternDescription) = detectPattern(
            dominantColors: dominantColors,
            warmCoolScore: globalWarmCoolScore,
            styleConsistencyScore: consistencyScore
        )
        
        return (consistencyScore, hasPattern, patternDescription)
    }
    
    /// 计算数组的标准差
    private func std(_ arr: [Float]) -> Float {
        guard !arr.isEmpty else { return 0 }
        let mean = arr.reduce(0, +) / Float(arr.count)
        let varSum = arr.map { pow($0 - mean, 2) }.reduce(0, +)
        return sqrt(varSum / Float(arr.count))
    }
    
    /// 计算风格一致性分数（0-1，越高越一致）
    private func computeStyleConsistencyScore(
        hueValues: [Float],
        saturationValues: [Float],
        lightnessValues: [Float],
        warmCoolScores: [Float]
    ) -> Float {
        let hueStd = std(hueValues)
        let satStd = std(saturationValues)
        let lightStd = std(lightnessValues)
        let warmCoolStd = std(warmCoolScores)
        
        // 映射成"越稳定 → 越高分"
        let invHue = 1 - min(hueStd / 0.25, 1)       // Hue 波动 > 0.25 基本就混乱
        let invSat = 1 - min(satStd / 0.20, 1)
        let invLight = 1 - min(lightStd / 0.20, 1)
        let invWarmCool = 1 - min(warmCoolStd / 0.30, 1)
        
        return max(0, min(1, (invHue + invSat + invLight + invWarmCool) / 4))
    }
    
    /// 检测是否有显著规律
    private func detectPattern(
        dominantColors: [DominantColor],
        warmCoolScore: Float,
        styleConsistencyScore: Float
    ) -> (hasPattern: Bool, patternDescription: String) {
        // 规则 1：色系占比是否特别集中（主色超过 45%）
        let mainColorDominant = dominantColors.contains { $0.weight > 0.45 }
        
        // 规则 2：冷暖是否明显偏向
        let strongWarmCool = abs(warmCoolScore) > 0.25
        
        // 规则 3：风格一致性需达到最低阈值
        let consistent = styleConsistencyScore >= 0.55
        
        if consistent && (mainColorDominant || strongWarmCool) {
            var desc = ""
            
            if mainColorDominant {
                if let dc = dominantColors.first(where: { $0.weight > 0.45 }) {
                    desc += "主色调集中在 \(dc.colorName)，占比显著偏高；"
                }
            }
            
            if strongWarmCool {
                desc += warmCoolScore > 0 ? "整体色温偏暖，呈现稳定暖色倾向；" :
                                            "整体色温偏冷，呈现持续冷色倾向；"
            }
            
            return (true, desc)
        }
        
        return (false, "")
    }
    
    /// 选择聚类中的代表性照片（最接近质心的照片）
    private func selectRepresentativePhotos(
        for cluster: ColorCluster,
        from allPhotos: [PhotoColorInfo],
        maxCount: Int
    ) -> [PhotoColorInfo] {
        // 筛选属于该聚类的照片
        let clusterPhotos = allPhotos.filter { $0.primaryClusterIndex == cluster.index }
        
        guard !clusterPhotos.isEmpty else { return [] }
        
        // 如果照片数量少于 maxCount，全部返回
        if clusterPhotos.count <= maxCount {
            return clusterPhotos
        }
        
        // 计算每张照片与质心的距离
        let photosWithDistance = clusterPhotos.map { photo -> (photo: PhotoColorInfo, distance: Float) in
            // 使用照片的第一个主色（权重最大的颜色）与质心比较
            guard let firstColor = photo.dominantColors.first else {
                return (photo, Float.infinity)
            }
            
            let distance = simd_distance(firstColor.rgb, cluster.centroid)
            return (photo, distance)
        }
        
        // 按距离排序，选择最接近的 maxCount 张
        let sortedPhotos = photosWithDistance.sorted { $0.distance < $1.distance }
        return sortedPhotos.prefix(maxCount).map { $0.photo }
    }
}
