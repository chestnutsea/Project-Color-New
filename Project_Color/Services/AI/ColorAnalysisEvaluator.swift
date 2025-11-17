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
        print("🎨 开始 AI 颜色评价（流式）...")
        
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
                DeepSeekService.ChatRequest.Message(role: "system", content: "你是专业色彩分析师。"),
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
    
    // MARK: - Private Methods
    
    /// 评价整体色彩组成
    private func evaluateOverallComposition(clusters: [ColorCluster]) async throws -> OverallEvaluation {
        // 构建颜色数据
        var colorData: [[String: Any]] = []
        for cluster in clusters {
            let lab = colorConverter.rgbToLab(cluster.centroid)
            let hsl = rgbToHSL(cluster.centroid)
            
            colorData.append([
                "name": cluster.colorName,
                "hex": cluster.hex,
                "photoCount": cluster.photoCount,
                "hue": hsl.h,
                "saturation": hsl.s,
                "lightness": hsl.l,
                "lab_L": lab.x,
                "lab_a": lab.y,
                "lab_b": lab.z
            ])
        }
        
        // 构建提示词
        let systemPrompt = """
        你是一位专业的色彩分析师，擅长从色调、饱和度、明度等方面评价照片的色彩组成。
        你的评价应该：
        1. 准确、专业、有洞察力
        2. 从色调分布、饱和度特征、明度层次三个维度分析
        3. 使用中文，语言优美但不过度修饰
        4. 长度控制在 150-250 字
        """
        
        let userMessage = """
        请评价以下照片集的整体色彩组成。这些是从照片中提取的代表色：
        
        \(formatColorDataForPrompt(colorData))
        
        请从以下维度进行评价：
        1. **色调（Hue）**: 主要色调是什么？色调分布是集中还是分散？冷暖倾向如何？
        2. **饱和度（Saturation）**: 整体饱和度偏高还是偏低？色彩是鲜艳明快还是柔和淡雅？
        3. **明度（Lightness/Brightness）**: 明度层次如何？是高调、中调还是低调？对比度如何？
        
        请给出简洁专业的评价（150-250字）。
        """
        
        // 调用 API
        let response = try await deepSeekService.chat(
            systemPrompt: systemPrompt,
            userMessage: userMessage
        )
        
        return OverallEvaluation(
            hueAnalysis: extractSection(from: response, keyword: "色调"),
            saturationAnalysis: extractSection(from: response, keyword: "饱和度"),
            brightnessAnalysis: extractSection(from: response, keyword: "明度"),
            fullText: response
        )
    }
    
    /// 评价单个色系簇
    private func evaluateCluster(cluster: ColorCluster) async throws -> ClusterEvaluation {
        let lab = colorConverter.rgbToLab(cluster.centroid)
        let hsl = rgbToHSL(cluster.centroid)
        
        let systemPrompt = """
        你是一位专业的色彩分析师。请用简洁、专业的语言评价单个颜色。
        评价应该：
        1. 描述这个颜色的视觉特征和情感表达
        2. 分析其色调、饱和度、明度特点
        3. 使用中文，50-80字
        """
        
        let userMessage = """
        请评价这个颜色：
        - 颜色名称: \(cluster.colorName)
        - Hex: \(cluster.hex)
        - 色调(Hue): \(String(format: "%.1f°", hsl.h))
        - 饱和度(Saturation): \(String(format: "%.1f%%", hsl.s))
        - 明度(Lightness): \(String(format: "%.1f%%", hsl.l))
        - Lab: L=\(String(format: "%.1f", lab.x)), a=\(String(format: "%.1f", lab.y)), b=\(String(format: "%.1f", lab.z))
        - 照片数量: \(cluster.photoCount) 张
        
        请给出简洁的色彩评价（50-80字）。
        """
        
        let response = try await deepSeekService.chat(
            systemPrompt: systemPrompt,
            userMessage: userMessage
        )
        
        return ClusterEvaluation(
            clusterIndex: cluster.index,
            colorName: cluster.colorName,
            hexValue: cluster.hex,
            evaluation: response.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    // MARK: - Helper Methods
    
    /// 将颜色数据格式化为提示词
    private func formatColorDataForPrompt(_ colorData: [[String: Any]]) -> String {
        var result = ""
        for (index, data) in colorData.enumerated() {
            let name = data["name"] as? String ?? "未知"
            let hex = data["hex"] as? String ?? "#000000"
            let count = data["photoCount"] as? Int ?? 0
            let hue = data["hue"] as? Float ?? 0
            let sat = data["saturation"] as? Float ?? 0
            let light = data["lightness"] as? Float ?? 0
            
            result += """
            色系 \(index + 1): \(name) (\(hex))
              - 照片数量: \(count) 张
              - 色调: \(String(format: "%.1f°", hue))
              - 饱和度: \(String(format: "%.1f%%", sat))
              - 明度: \(String(format: "%.1f%%", light))
            
            """
        }
        return result
    }
    
    /// 从响应中提取特定部分（简单实现）
    private func extractSection(from text: String, keyword: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var result: [String] = []
        var capturing = false
        
        for line in lines {
            if line.contains(keyword) || line.contains("**\(keyword)") {
                capturing = true
            }
            
            if capturing {
                result.append(line)
                // 如果遇到下一个关键词或者空行，停止捕获
                if result.count > 1 && (line.isEmpty || line.contains("**")) {
                    break
                }
            }
        }
        
        if result.isEmpty {
            return text  // 如果没有找到特定部分，返回全文
        }
        
        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// RGB 转 HSL
    private func rgbToHSL(_ rgb: SIMD3<Float>) -> (h: Float, s: Float, l: Float) {
        let r = rgb.x
        let g = rgb.y
        let b = rgb.z
        
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        // Lightness
        let l = (maxC + minC) / 2.0
        
        // Saturation
        var s: Float = 0
        if delta > 0.00001 {
            s = delta / (1 - abs(2 * l - 1))
        }
        
        // Hue
        var h: Float = 0
        if delta > 0.00001 {
            if maxC == r {
                h = 60 * fmod((g - b) / delta, 6)
            } else if maxC == g {
                h = 60 * ((b - r) / delta + 2)
            } else {
                h = 60 * ((r - g) / delta + 4)
            }
        }
        
        if h < 0 {
            h += 360
        }
        
        return (h: h, s: s * 100, l: l * 100)
    }
    
    // MARK: - 新的评价方法（基于统计数据）
    
    /// 使用统计数据评价整体色彩组成
    private func evaluateOverallCompositionWithStatistics(
        result: AnalysisResult,
        globalStats: GlobalColorStatistics,
        clusterAnalytics: [ClusterAnalytics]
    ) async throws -> OverallEvaluation {
        
        let prompt = generateStatisticsBasedPrompt(
            result: result,
            globalStats: globalStats,
            clusterAnalytics: clusterAnalytics
        )
        
        let messages = [
            DeepSeekService.ChatRequest.Message(role: "system", content: "你是一位专业的色彩分析师和视觉美学顾问。"),
            DeepSeekService.ChatRequest.Message(role: "user", content: prompt)
        ]
        
        let response = try await deepSeekService.sendChatRequest(messages: messages, temperature: 0.7)
        
        return OverallEvaluation(
            hueAnalysis: response,
            saturationAnalysis: "",
            brightnessAnalysis: "",
            fullText: response
        )
    }
    
    /// 使用统计数据评价单个聚类
    private func evaluateClusterWithStatistics(
        analytics: ClusterAnalytics,
        allAnalytics: [ClusterAnalytics]
    ) async throws -> ClusterEvaluation {
        
        let cluster = analytics.cluster
        let stats = analytics.statistics
        
        let prompt = """
        请简要评价以下色彩聚类（1-2句话）：
        
        **聚类信息**
        - 颜色：\(cluster.colorName) (\(cluster.hex))
        - 照片数量：\(stats.photoCount) 张
        - 色相范围：\(String(format: "%.1f°-%.1f°", stats.hueRange.min, stats.hueRange.max))
        - 明度范围：\(String(format: "%.2f-%.2f", stats.lightnessRange.min, stats.lightnessRange.max))
        - 饱和度范围：\(String(format: "%.2f-%.2f", stats.saturationRange.min, stats.saturationRange.max))
        - 内部一致性：\(String(format: "%.2f", stats.consistency))
        
        请从色彩特征和视觉氛围角度进行简要描述。
        """
        
        let messages = [
            DeepSeekService.ChatRequest.Message(role: "system", content: "你是一位专业的色彩分析师。"),
            DeepSeekService.ChatRequest.Message(role: "user", content: prompt)
        ]
        
        let response = try await deepSeekService.sendChatRequest(messages: messages, temperature: 0.7)
        
        return ClusterEvaluation(
            clusterIndex: cluster.index,
            colorName: cluster.colorName,
            hexValue: cluster.hex,
            evaluation: response
        )
    }
    
    /// 生成基于统计数据的 prompt（方案A：包含代表性照片）
    private func generateStatisticsBasedPrompt(
        result: AnalysisResult,
        globalStats: GlobalColorStatistics,
        clusterAnalytics: [ClusterAnalytics]
    ) -> String {
        // 方案A：发送聚类统计 + 代表性照片的主色
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
        
        // 精简的分析要求（增加颜色规律分析）
        prompt += """
        
        
        **请提供**：
        1. 整体色彩风格特征（2-3句）
        2. 各聚类的视觉氛围（每个1句）
        3. 聚类间的色彩关系（互补/类似/对比）
        4. **颜色规律**：
           - 代表照片内部的主色搭配规律（如：主色+辅色的组合模式）
           - 跨聚类的色彩演变趋势（如：明度递减、饱和度渐变）
           - 色相分布的系统性特征（如：类似色系、对比色系、三角配色）
        5. 可能的摄影/绘画风格
        
        请简洁专业地输出，使用色彩学术语。
        """
        
        return prompt
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

