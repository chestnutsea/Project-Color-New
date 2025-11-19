//
//  AnalysisResultView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 1: 分析结果展示页面
//

import SwiftUI
import Photos
#if canImport(UIKit)
import UIKit
#endif
import simd

private enum AnalysisResultTab: String, CaseIterable, Identifiable {
    case color = "色彩"
    case distribution = "分布"
    case aiEvaluation = "AI评价"
    
    var id: Self { self }
}

// MARK: - Layout Constants
private enum KeywordTagLayout {
    static let fontSize: CGFloat = 16
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 5
    static let cornerRadius: CGFloat = 5
    static let spacing: CGFloat = 8
}

struct AnalysisResultView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var result: AnalysisResult
    @State private var selectedCluster: ColorCluster?
    @State private var selectedTab: AnalysisResultTab = .color
    @State private var show3DView = false
    
    // 缓存计算密集的属性
    @State private var cachedHueRingPoints: [HueRingPoint] = []
    @State private var cachedScatterPoints: [SaturationBrightnessPoint] = []
    @State private var cachedColorSpacePoints: [ColorSpacePoint] = []
    @State private var isDistributionDataReady = false
    
    private let labConverter = ColorSpaceConverter()
    private let normalizedLabBounds = (
        min: SIMD3<Float>(repeating: -0.5),
        max: SIMD3<Float>(repeating: 0.5)
    )
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("结果视图", selection: $selectedTab) {
                        ForEach(AnalysisResultTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Group {
                        switch selectedTab {
                        case .color:
                            colorTabContent
                        case .distribution:
                            distributionTabContent
                        case .aiEvaluation:
                            aiEvaluationTabContent
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("分析结果")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedCluster) { cluster in
            ClusterDetailView(cluster: cluster, result: result)
        }
        .sheet(isPresented: $show3DView) {
            threeDView(points: cachedColorSpacePoints)
        }
        .onAppear {
            // 在后台计算分布数据
            if !isDistributionDataReady {
                Task.detached(priority: .userInitiated) {
                    let huePoints = await computeHueRingPoints()
                    let scatterPts = await computeScatterPoints()
                    let spacePts = await computeColorSpacePoints()
                    
                    await MainActor.run {
                        cachedHueRingPoints = huePoints
                        cachedScatterPoints = scatterPts
                        cachedColorSpacePoints = spacePts
                        isDistributionDataReady = true
                    }
                }
            }
        }
    }
    
    // MARK: - Tab 内容
    private var colorTabContent: some View {
        VStack(spacing: 20) {
            headerSection
            qualitySection
            
            if result.clusters.count < result.optimalK {
                clusterReductionWarning
            }
            
            clustersSection
            
            if result.failedCount > 0 {
                failedSection
            }
        }
    }
    
    private var distributionTabContent: some View {
        VStack(spacing: 20) {
            if isDistributionDataReady {
                HueRingDistributionView(
                    points: cachedHueRingPoints,
                    dominantHue: dominantHue,
                    primaryColor: dominantCluster?.color,
                    onPresent3D: cachedColorSpacePoints.isEmpty ? nil : {
                        show3DView = true
                    }
                )
                
                SaturationBrightnessScatterView(
                    points: cachedScatterPoints,
                    hue: dominantHue
                )
            } else {
                ProgressView("正在计算分布数据...")
                    .padding()
            }
            
            // 冷暖色调直方图
            if let warmCoolDist = result.warmCoolDistribution,
               !warmCoolDist.scores.isEmpty,
               let dominantCluster = dominantCluster,
               let (hue, saturation, brightness) = getDominantClusterHSB(dominantCluster) {
                WarmCoolHistogramView(
                    distribution: warmCoolDist,
                    dominantClusterHue: hue,
                    dominantClusterSaturation: saturation,
                    dominantClusterBrightness: brightness
                )
            } else if result.isCompleted {
                // 调试信息：显示为什么没有显示直方图
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(.orange)
                        Text("冷暖色调分析")
                            .font(.headline)
                    }
                    
                    if result.warmCoolDistribution == nil {
                        Text("暂无冷暖评分数据")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if result.warmCoolDistribution?.scores.isEmpty == true {
                        Text("评分数据为空")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if dominantCluster == nil {
                        Text("无代表色簇")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("3D 视图展示的是 LCh 色彩空间（Lab 的极坐标形式），这种表示方式更符合人眼对颜色的感知。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• H (色相): 0-360°，表示颜色类型（红、橙、黄、绿、青、蓝、紫）")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• C (色度): 0-110，表示颜色的鲜艳程度（饱和感）")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• L (亮度): 0-100，表示颜色的明暗程度")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var aiEvaluationTabContent: some View {
        VStack(spacing: 20) {
            if let evaluation = result.aiEvaluation {
                if evaluation.isLoading {
                    // 加载状态
                    aiLoadingView
                } else if let error = evaluation.error {
                    // 错误状态
                    aiErrorView(error: error)
                } else {
                    // 评价内容
                    if let overall = evaluation.overallEvaluation {
                        overallEvaluationCard(overall)
                    }
                    
                    if !evaluation.clusterEvaluations.isEmpty {
                        clusterEvaluationsSection(evaluation.clusterEvaluations)
                    }
                }
            } else {
                // 初始状态（正在生成）
                aiLoadingView
            }
        }
    }
    
    private var aiLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("AI 正在分析色彩组成...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("这可能需要几秒钟")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func aiErrorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("AI 评价失败")
                .font(.headline)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重新尝试") {
                retryAIEvaluation()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func overallEvaluationCard(_ overall: OverallEvaluation) -> some View {
        // 获取主代表色（照片数量最多的聚类）
        let dominantColor = getDominantClusterColor()
        
        return VStack(alignment: .leading, spacing: 20) {
            // 解析并格式化显示评价内容
            formattedEvaluationView(overall.fullText, dominantColor: dominantColor)
        }
        .padding()
    }
    
    // 获取主代表色（照片数量最多的聚类的颜色）
    private func getDominantClusterColor() -> Color {
        let clusters = result.clusters
        guard !clusters.isEmpty else {
            return Color.purple
        }
        
        // 找到照片数量最多的聚类
        guard let dominantCluster = clusters.max(by: { $0.photoCount < $1.photoCount }) else {
            return Color.purple
        }
        
        // 将 RGB 转换为 Color
        let rgb = dominantCluster.centroid
        return Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
    }
    
    // 解析并格式化显示评价内容
    private func formattedEvaluationView(_ text: String, dominantColor: Color) -> some View {
        // 分离关键词和正文
        let (mainText, keywordsText) = parseTextAndKeywords(text)
        
        return VStack(alignment: .leading, spacing: 20) {
            // 关键词 tag 显示在最上方（背景色区域外）
            if !keywordsText.isEmpty {
                keywordTagsView(keywordsText)
                    .padding(.bottom, 10)
            }
            
            // 正文显示在彩色背景区域内
            if !mainText.isEmpty {
                Text(mainText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .background(dominantColor.opacity(0.08))
                    .cornerRadius(KeywordTagLayout.cornerRadius)
            }
        }
    }
    
    // 分离正文和关键词
    private func parseTextAndKeywords(_ text: String) -> (mainText: String, keywords: String) {
        // 查找"风格关键词："标记
        if let range = text.range(of: "风格关键词：") {
            let mainText = String(text[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let keywords = String(text[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (mainText, keywords)
        }
        
        // 如果没有找到标记，全部作为正文
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), "")
    }
    
    // 将关键词显示为彩色 tag
    private func keywordTagsView(_ text: String) -> some View {
        let keywordItems = parseKeywordsWithColors(text)
        
        return FlowLayout(spacing: KeywordTagLayout.spacing) {
            ForEach(keywordItems.indices, id: \.self) { index in
                let item = keywordItems[index]
                
                Text(item.keyword)
                    .font(.system(size: KeywordTagLayout.fontSize))
                    .fontWeight(.medium)
                    .padding(.horizontal, KeywordTagLayout.horizontalPadding)
                    .padding(.vertical, KeywordTagLayout.verticalPadding)
                    .background(item.color.opacity(0.2))
                    .foregroundColor(item.color.opacity(0.9))
                    .cornerRadius(KeywordTagLayout.cornerRadius)
            }
        }
    }
    
    // 解析关键词和颜色（格式：关键词#颜色值）
    private func parseKeywordsWithColors(_ text: String) -> [(keyword: String, color: Color)] {
        let items = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return items.enumerated().map { index, item in
            // 尝试分割关键词和颜色值
            let parts = item.components(separatedBy: "#")
            let keyword = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if parts.count > 1 {
                // 有颜色值，解析十六进制颜色
                let hexColor = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if let color = Color(hex: hexColor) {
                    return (keyword, color)
                }
            }
            
            // 没有颜色值或解析失败，使用默认颜色
            let defaultColors: [Color] = [.blue, .purple, .green, .orange, .pink, .teal, .indigo]
            return (keyword, defaultColors[index % defaultColors.count])
        }
    }
    
    
    // FlowLayout - 自动换行的布局（支持分散对齐）
    struct FlowLayout: Layout {
        var spacing: CGFloat = 8
        var justify: Bool = true  // 是否分散对齐
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let result = FlowResult(
                in: proposal.replacingUnspecifiedDimensions().width,
                subviews: subviews,
                spacing: spacing,
                justify: justify
            )
            return result.size
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let result = FlowResult(
                in: bounds.width,
                subviews: subviews,
                spacing: spacing,
                justify: justify
            )
            for (index, subview) in subviews.enumerated() {
                subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                         y: bounds.minY + result.positions[index].y),
                             proposal: .unspecified)
            }
        }
        
        struct FlowResult {
            var size: CGSize = .zero
            var positions: [CGPoint] = []
            
            init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat, justify: Bool) {
                var lines: [[Int]] = [[]]  // 每行的 subview 索引
                var lineSizes: [[CGSize]] = [[]]  // 每行每个元素的尺寸
                var currentLineWidth: CGFloat = 0
                var lineHeights: [CGFloat] = []
                
                // 第一步：分组到各行
                for (index, subview) in subviews.enumerated() {
                    let size = subview.sizeThatFits(.unspecified)
                    
                    if currentLineWidth + size.width > maxWidth && !lines.last!.isEmpty {
                        // 换行
                        lines.append([])
                        lineSizes.append([])
                        currentLineWidth = 0
                    }
                    
                    lines[lines.count - 1].append(index)
                    lineSizes[lineSizes.count - 1].append(size)
                    currentLineWidth += size.width + (lines.last!.count > 1 ? spacing : 0)
                }
                
                // 第二步：计算每行的位置（支持分散对齐）
                var y: CGFloat = 0
                
                for (lineIndex, lineIndices) in lines.enumerated() {
                    let sizes = lineSizes[lineIndex]
                    let lineHeight = sizes.map { $0.height }.max() ?? 0
                    lineHeights.append(lineHeight)
                    
                    // 计算该行内容的总宽度
                    let totalContentWidth = sizes.reduce(0) { $0 + $1.width }
                    
                    let isLastLine = (lineIndex == lines.count - 1)
                    let itemCount = lineIndices.count
                    
                    // 计算间距和起始位置
                    var actualSpacing = spacing
                    var startX: CGFloat = 0
                    
                    if justify && !isLastLine && itemCount > 1 {
                        // 非最后一行：分散对齐
                        let availableSpace = maxWidth - totalContentWidth
                        actualSpacing = availableSpace / CGFloat(itemCount - 1)
                        startX = 0
                    } else if itemCount > 1 {
                        // 最后一行或未启用分散对齐：居中对齐
                        let totalLineWidth = totalContentWidth + spacing * CGFloat(itemCount - 1)
                        startX = (maxWidth - totalLineWidth) / 2
                    }
                    
                    var x = startX
                    for (i, index) in lineIndices.enumerated() {
                        positions.append(CGPoint(x: x, y: y))
                        x += sizes[i].width
                        if i < itemCount - 1 {
                            x += actualSpacing
                        }
                    }
                    
                    y += lineHeight + spacing
                }
                
                self.size = CGSize(width: maxWidth, height: y - spacing)
            }
        }
    }
    
    private func clusterEvaluationsSection(_ evaluations: [ClusterEvaluation]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("各色系评价")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(evaluations.count) 个色系")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ForEach(evaluations) { clusterEval in
                clusterEvaluationCard(clusterEval)
            }
        }
    }
    
    private func clusterEvaluationCard(_ clusterEval: ClusterEvaluation) -> some View {
        HStack(alignment: .top, spacing: 15) {
            // 色块
            RoundedRectangle(cornerRadius: 10)
                .fill(colorFromHex(clusterEval.hexValue))
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // 评价内容
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(clusterEval.colorName)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(clusterEval.hexValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospaced()
                }
                
                Text(clusterEval.evaluation)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // Helper: 从 Hex 字符串创建 Color
    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    // 重试 AI 评价
    private func retryAIEvaluation() {
        Task {
            await MainActor.run {
                result.aiEvaluation = ColorEvaluation(isLoading: true)
            }
            
            let evaluator = ColorAnalysisEvaluator()
            do {
                let evaluation = try await evaluator.evaluateColorAnalysis(
                    result: result,
                    onUpdate: { @MainActor updatedEvaluation in
                        // 实时更新 UI（流式显示）
                        result.aiEvaluation = updatedEvaluation
                    }
                )
                await MainActor.run {
                    result.aiEvaluation = evaluation
                }
            } catch {
                await MainActor.run {
                    var errorEvaluation = ColorEvaluation()
                    errorEvaluation.isLoading = false
                    errorEvaluation.error = error.localizedDescription
                    result.aiEvaluation = errorEvaluation
                }
            }
        }
    }
    
    // MARK: - 异步计算方法
    
    private func computeScatterPoints() async -> [SaturationBrightnessPoint] {
        result.photoInfos.compactMap { photo -> SaturationBrightnessPoint? in
            guard !photo.dominantColors.isEmpty else { return nil }
            
            var weightedSaturation: Float = 0
            var weightedBrightness: Float = 0
            var totalWeight: Float = 0
            
            for dominantColor in photo.dominantColors {
                let uiColor = UIColor(
                    red: CGFloat(dominantColor.rgb.x),
                    green: CGFloat(dominantColor.rgb.y),
                    blue: CGFloat(dominantColor.rgb.z),
                    alpha: 1.0
                )
                
                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0
                
                guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
                    continue
                }
                
                let weight = max(dominantColor.weight, 0.0001)
                weightedSaturation += Float(saturation) * weight
                weightedBrightness += Float(brightness) * weight
                totalWeight += weight
            }
            
            guard totalWeight > 0 else { return nil }
            
            let sat = CGFloat(weightedSaturation / totalWeight) * 255.0
            let bri = CGFloat(weightedBrightness / totalWeight) * 255.0
            
            return SaturationBrightnessPoint(saturation: sat, brightness: bri)
        }
    }
    
    private var dominantCluster: ColorCluster? {
        result.clusters.max(by: { $0.photoCount < $1.photoCount })
    }
    
    // 获取 dominant cluster 的 HSB 值
    private func getDominantClusterHSB(_ cluster: ColorCluster) -> (hue: Float, saturation: Float, brightness: Float)? {
        let uiColor = UIColor(
            red: CGFloat(cluster.centroid.x),
            green: CGFloat(cluster.centroid.y),
            blue: CGFloat(cluster.centroid.z),
            alpha: 1.0
        )
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return nil
        }
        
        return (
            hue: Float(hue * 360),
            saturation: Float(saturation),
            brightness: Float(brightness)
        )
    }
    
    private var dominantHue: Double? {
        guard let cluster = dominantCluster else { return nil }
        
        let uiColor = UIColor(
            red: CGFloat(cluster.centroid.x),
            green: CGFloat(cluster.centroid.y),
            blue: CGFloat(cluster.centroid.z),
            alpha: 1.0
        )
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return nil
        }
        
        return Double(hue)
    }
    
    private func computeHueRingPoints() async -> [HueRingPoint] {
        result.photoInfos.flatMap { photoInfo in
            photoInfo.dominantColors.compactMap { dominantColor -> HueRingPoint? in
                let uiColor = UIColor(
                    red: CGFloat(dominantColor.rgb.x),
                    green: CGFloat(dominantColor.rgb.y),
                    blue: CGFloat(dominantColor.rgb.z),
                    alpha: 1.0
                )
                
                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0
                
                guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
                    return nil
                }
                
                return HueRingPoint(
                    hue: Double(hue),
                    weight: Double(max(0, min(1, dominantColor.weight))),
                    color: dominantColor.color.opacity(0.7)
                )
            }
        }
    }
    
    private func computeColorSpacePoints() async -> [ColorSpacePoint] {
        result.photoInfos.flatMap { photoInfo in
            photoInfo.dominantColors.compactMap { dominantColor -> ColorSpacePoint? in
                let weight = Double(max(0, min(1, dominantColor.weight)))
                guard weight > 0 else { return nil }
                
                let hex = DominantColor.rgbToHex(dominantColor.rgb)
                let percentage = Int(round(weight * 100))
                let info = "\(hex) • \(percentage)%"
                
                let position = normalizedLChPosition(for: dominantColor.rgb)
                let uiColor = UIColor(
                    red: CGFloat(dominantColor.rgb.x),
                    green: CGFloat(dominantColor.rgb.y),
                    blue: CGFloat(dominantColor.rgb.z),
                    alpha: 1.0
                )
                return ColorSpacePoint(
                    position: position,
                    weight: weight,
                    label: info,
                    displayColor: uiColor.cgColor
                )
            }
        }
    }
    
    private func normalizedLChPosition(for rgb: SIMD3<Float>) -> SIMD3<Float> {
        // 1. RGB → Lab
        let lab = labConverter.rgbToLab(rgb)
        
        // 2. Lab → LCh
        let L = lab.x  // 亮度 (0-100)
        let a = lab.y
        let b = lab.z
        
        // C (色度) = sqrt(a² + b²)
        let C = sqrtf(a * a + b * b)  // 通常 0-110
        
        // h (色相角度) = atan2(b, a) 转为 0-360°
        var h = atan2(b, a) * (180.0 / Float.pi)
        if h < 0 {
            h += 360.0
        }
        
        // 3. 归一化到 [-0.5, 0.5] 范围
        // X = h (0-360°) → [-0.5, 0.5]
        // 色相是圆周，映射到整个 X 轴范围
        let normalizedH = (h / 360.0) - 0.5
        
        // Y = C (0-110) → [-0.5, 0.5]
        // 色度：0 在底部 (-0.5)，110 在顶部 (0.5)
        let normalizedC = (C / 110.0) - 0.5
        
        // Z = L (0-100) → [-0.5, 0.5]
        // 亮度：0 在后方 (-0.5)，100 在前方 (0.5)
        let normalizedL = (L / 100.0) - 0.5
        
        let normalized = SIMD3<Float>(normalizedH, normalizedC, normalizedL)
        return simd_clamp(normalized, normalizedLabBounds.min, normalizedLabBounds.max)
    }
    
    // MARK: - 头部信息
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("分析完成")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(result.processedCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("张照片")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack(spacing: 30) {
                StatItem(label: "识别色系", value: "\(result.clusters.count)")
                StatItem(label: "成功处理", value: "\(result.processedCount)")
                if result.failedCount > 0 {
                    StatItem(label: "处理失败", value: "\(result.failedCount)", color: .orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Phase 4: 聚类质量指标
    private var qualitySection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: qualityIcon)
                    .font(.title2)
                    .foregroundColor(qualityColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("聚类质量")
                            .font(.headline)
                        
                        Text(result.qualityLevel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(qualityColor)
                    }
                    
                    Text(result.qualityDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最优色系数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("K = \(result.optimalK)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("轮廓系数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.3f", result.silhouetteScore))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(qualityColor)
                }
            }
            
            // 显示各K值得分（可折叠）
            if !result.allKScores.isEmpty && result.allKScores.count > 1 {
                DisclosureGroup("查看各K值得分") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.allKScores.sorted(by: { $0.key < $1.key }), id: \.key) { k, score in
                            HStack {
                                Text("K=\(k)")
                                    .font(.caption)
                                    .foregroundColor(k == result.optimalK ? .blue : .secondary)
                                    .fontWeight(k == result.optimalK ? .bold : .regular)
                                
                                Spacer()
                                
                                Text(String(format: "%.4f", score))
                                    .font(.caption)
                                    .foregroundColor(k == result.optimalK ? .blue : .secondary)
                                
                                if k == result.optimalK {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.caption)
                .accentColor(.blue)
            }
        }
        .padding()
        .background(qualityBackgroundColor)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 质量等级图标
    private var qualityIcon: String {
        switch result.qualityLevel {
        case "优秀": return "star.circle.fill"
        case "良好": return "checkmark.circle.fill"
        case "一般": return "exclamationmark.circle.fill"
        case "较差": return "xmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    // 质量等级颜色
    private var qualityColor: Color {
        switch result.qualityLevel {
        case "优秀": return .green
        case "良好": return .blue
        case "一般": return .orange
        case "较差": return .red
        default: return .gray
        }
    }
    
    // 质量等级背景色
    private var qualityBackgroundColor: Color {
        switch result.qualityLevel {
        case "优秀": return Color.green.opacity(0.05)
        case "良好": return Color.blue.opacity(0.05)
        case "一般": return Color.orange.opacity(0.05)
        case "较差": return Color.red.opacity(0.05)
        default: return Color(.systemBackground)
        }
    }
    
    // MARK: - 色系数量减少提示
    private var clusterReductionWarning: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("色系数量变化")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("初始识别 \(result.optimalK) 个色系，最终保留 \(result.clusters.count) 个")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("可能原因：")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        ReasonItem(icon: "arrow.merge", text: "相似色系被合并（色差 < 阈值）")
                        ReasonItem(icon: "trash", text: "小簇被删除（照片数 < 最小簇大小）")
                        ReasonItem(icon: "tag", text: "名称相似的色系被合并")
                    }
                    
                    Divider()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.caption)
                        Text("可在设置中调整合并阈值、最小簇大小等参数")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 聚类结果
    private var clustersSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            let nonEmptyClusters = result.clusters.filter { $0.photoCount > 0 }
            
            HStack {
                Text("色彩分类")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(nonEmptyClusters.count) 个色系")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if nonEmptyClusters.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(nonEmptyClusters.sorted(by: { $0.photoCount > $1.photoCount })) { cluster in
                    ClusterCard(
                        cluster: cluster,
                        representativePhotos: getRepresentativePhotos(for: cluster)
                    )
                    .onTapGesture {
                        selectedCluster = cluster
                    }
                }
            }
        }
    }
    
    /// 获取聚类的代表性照片（最接近质心的照片）
    private func getRepresentativePhotos(for cluster: ColorCluster, maxCount: Int = 3) -> [PHAsset] {
        // 筛选属于该聚类的照片
        let clusterPhotos = result.photoInfos.filter { $0.primaryClusterIndex == cluster.index }
        
        guard !clusterPhotos.isEmpty else { return [] }
        
        // 如果照片数量少于 maxCount，全部返回
        if clusterPhotos.count <= maxCount {
            return clusterPhotos.compactMap { photoInfo in
                fetchAsset(identifier: photoInfo.assetIdentifier)
            }
        }
        
        // 计算每张照片与质心的距离
        let photosWithDistance = clusterPhotos.compactMap { photo -> (photoInfo: PhotoColorInfo, distance: Float)? in
            guard let firstColor = photo.dominantColors.first else { return nil }
            let distance = simd_distance(firstColor.rgb, cluster.centroid)
            return (photo, distance)
        }
        
        // 按距离排序，选择最接近的 maxCount 张
        let sortedPhotos = photosWithDistance.sorted { $0.distance < $1.distance }
        return sortedPhotos.prefix(maxCount).compactMap { item in
            fetchAsset(identifier: item.photoInfo.assetIdentifier)
        }
    }
    
    /// 根据 identifier 获取 PHAsset
    private func fetchAsset(identifier: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject
    }
    
    // MARK: - 失败统计
    private var failedSection: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text("处理失败：\(result.failedCount) 张")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: result.timestamp)
    }
}

// MARK: - 统计项
struct StatItem: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 聚类卡片
struct ClusterCard: View {
    let cluster: ColorCluster
    let representativePhotos: [PHAsset]
    
    @State private var thumbnails: [UIImage] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 15) {
                // 色块
                RoundedRectangle(cornerRadius: 10)
                    .fill(cluster.color)
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                // 信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(cluster.colorName)
                        .font(.headline)
                    
                    Text(cluster.hex)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospaced()
                    
                    Text("\(cluster.photoCount) 张照片")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            
            // 代表性照片缩略图
            if !thumbnails.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(thumbnails.indices, id: \.self) { index in
                            Image(uiImage: thumbnails[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .onAppear {
            loadThumbnails()
        }
    }
    
    private func loadThumbnails() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        
        let targetSize = CGSize(width: 160, height: 160) // 2x for retina
        
        for asset in representativePhotos.prefix(3) {
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        self.thumbnails.append(image)
                    }
                }
            }
        }
    }
}

// MARK: - 聚类详情页
struct ClusterDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let cluster: ColorCluster
    let result: AnalysisResult
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 10)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 色块和信息
                    VStack(spacing: 15) {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(cluster.color)
                            .frame(height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        VStack(spacing: 8) {
                            Text(cluster.colorName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(cluster.hex)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospaced()
                            
                            Text("\(cluster.photoCount) 张照片")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    // 照片网格
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(photosInCluster, id: \.id) { photoInfo in
                            AnalysisPhotoThumbnail(assetIdentifier: photoInfo.assetIdentifier)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("类别详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var photosInCluster: [PhotoColorInfo] {
        let photos = result.photos(in: cluster.index)
        
        // 按与质心的距离排序（从近到远）
        return photos.sorted { photo1, photo2 in
            guard let color1 = photo1.dominantColors.first,
                  let color2 = photo2.dominantColors.first else {
                return false
            }
            
            let distance1 = simd_distance(color1.rgb, cluster.centroid)
            let distance2 = simd_distance(color2.rgb, cluster.centroid)
            return distance1 < distance2
        }
    }
}

// MARK: - 分析照片缩略图
struct AnalysisPhotoThumbnail: View {
    let assetIdentifier: String
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { img, _ in
            DispatchQueue.main.async {
                self.image = img
            }
        }
    }
}

#Preview {
    let result = AnalysisResult()
    result.totalPhotoCount = 10
    result.processedCount = 9
    result.failedCount = 1
    result.isCompleted = true
    result.clusters = [
        ColorCluster(index: 0, centroid: SIMD3<Float>(0.8, 0.2, 0.3), colorName: "红色", photoCount: 3),
        ColorCluster(index: 1, centroid: SIMD3<Float>(0.2, 0.6, 0.8), colorName: "蓝色", photoCount: 4),
        ColorCluster(index: 2, centroid: SIMD3<Float>(0.9, 0.8, 0.7), colorName: "米色", photoCount: 2)
    ]
    
    return AnalysisResultView(result: result)
}

// MARK: - 原因列表项
struct ReasonItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.orange)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Color Extension for Hex Parsing
extension Color {
    /// 从十六进制字符串创建 Color（支持 6 位格式，如 "FF5733"）
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        guard Scanner(string: hex).scanHexInt64(&int) else {
            return nil
        }
        
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (6 位)
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        default:
            return nil
        }
        
        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}
