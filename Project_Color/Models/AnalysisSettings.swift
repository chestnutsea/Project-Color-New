//
//  AnalysisSettings.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  用户可配置的分析设置
//

import Foundation
import Combine

/// 颜色分析设置
class AnalysisSettings: ObservableObject {
    
    static let shared = AnalysisSettings()
    
    // MARK: - 单图主色提取设置
    
    /// 单图主色提取算法
    enum ColorExtractionAlgorithm: String, Codable {
        case labWeighted = "感知模式"
        case medianCut = "快速模式"
    }
    
    /// 处理精度
    enum ExtractionQuality: String, Codable {
        case fast = "快速"
        case balanced = "平衡"
        case fine = "精细"
    }
    
    @Published var colorExtractionAlgorithm: ColorExtractionAlgorithm? = nil
    @Published var extractionQuality: ExtractionQuality? = nil
    @Published var autoMergeSimilarColors: Bool? = nil
    
    // MARK: - 自适应聚类设置
    
    /// 是否启用自适应聚类
    /// - 默认: true
    /// - 说明: 关闭后，将保留全局聚类的原始结果，不进行合并/删除操作
    @Published var enableAdaptiveClustering: Bool? = nil
    
    /// 合并阈值（ΔE₀₀）
    /// - 默认: 12.0
    /// - 范围: 5.0 - 25.0
    /// - 说明: 值越小，合并越严格，簇越多
    @Published var mergeThresholdDeltaE: Float? = nil
    
    /// 是否启用颜色名称相似性检查
    /// - 默认: true
    /// - 说明: 启用时，只合并名称相似的簇（如 DarkBlue + LightBlue）
    @Published var useColorNameSimilarity: Bool? = nil
    
    /// 最小簇大小
    /// - 默认: 2
    /// - 范围: 1 - 5
    /// - 说明: 照片数少于此值的簇会被删除
    @Published var minClusterSize: Int? = nil
    
    // MARK: - 默认值
    
    private let defaultColorExtractionAlgorithm: ColorExtractionAlgorithm = .labWeighted
    private let defaultExtractionQuality: ExtractionQuality = .balanced
    private let defaultAutoMergeSimilarColors: Bool = true
    
    private let defaultEnableAdaptiveClustering: Bool = true
    private let defaultMergeThreshold: Float = 12.0
    private let defaultUseColorNameSimilarity: Bool = true
    private let defaultMinClusterSize: Int = 2
    
    // MARK: - 获取实际使用的值
    
    /// 获取实际使用的主色提取算法
    var effectiveColorExtractionAlgorithm: ColorExtractionAlgorithm {
        return colorExtractionAlgorithm ?? defaultColorExtractionAlgorithm
    }
    
    /// 获取实际使用的提取精度
    var effectiveExtractionQuality: ExtractionQuality {
        return extractionQuality ?? defaultExtractionQuality
    }
    
    /// 获取实际使用的自动合并相似色设置
    var effectiveAutoMergeSimilarColors: Bool {
        return autoMergeSimilarColors ?? defaultAutoMergeSimilarColors
    }
    
    /// 获取实际使用的自适应聚类开关
    var effectiveEnableAdaptiveClustering: Bool {
        return enableAdaptiveClustering ?? defaultEnableAdaptiveClustering
    }
    
    /// 获取实际使用的合并阈值
    var effectiveMergeThreshold: Float {
        return mergeThresholdDeltaE ?? defaultMergeThreshold
    }
    
    /// 获取实际使用的名称相似性设置
    var effectiveUseColorNameSimilarity: Bool {
        return useColorNameSimilarity ?? defaultUseColorNameSimilarity
    }
    
    /// 获取实际使用的最小簇大小
    var effectiveMinClusterSize: Int {
        return minClusterSize ?? defaultMinClusterSize
    }
    
    // MARK: - 重置为默认值
    
    func resetToDefaults() {
        colorExtractionAlgorithm = nil
        extractionQuality = nil
        autoMergeSimilarColors = nil
        enableAdaptiveClustering = nil
        mergeThresholdDeltaE = nil
        useColorNameSimilarity = nil
        minClusterSize = nil
    }
    
    // MARK: - 获取配置描述
    
    var configurationDescription: String {
        var parts: [String] = []
        
        if let threshold = mergeThresholdDeltaE {
            parts.append("合并阈值: \(String(format: "%.1f", threshold))")
        }
        
        if let similarity = useColorNameSimilarity {
            parts.append("名称相似性: \(similarity ? "开启" : "关闭")")
        }
        
        if let minSize = minClusterSize {
            parts.append("最小簇大小: \(minSize)")
        }
        
        if parts.isEmpty {
            return "使用默认配置"
        } else {
            return parts.joined(separator: " • ")
        }
    }
    
    // MARK: - 预设配置
    
    /// 精细分类（更多簇）
    func applyFineGrainedPreset() {
        mergeThresholdDeltaE = 8.0
        useColorNameSimilarity = false
        minClusterSize = 1
    }
    
    /// 简洁分类（更少簇）
    func applySimplifiedPreset() {
        mergeThresholdDeltaE = 18.0
        useColorNameSimilarity = true
        minClusterSize = 3
    }
    
    /// 平衡分类（默认）
    func applyBalancedPreset() {
        resetToDefaults()
    }
    
    /// 单色系细分（适合颜色相近的照片）
    func applyMonochromePreset() {
        enableAdaptiveClustering = false  // ✅ 关闭自适应聚类，保留原始 K 值结果
        mergeThresholdDeltaE = 6.0   // 非常严格，保留细微差异
        useColorNameSimilarity = false  // 不看名称，只看色差
        minClusterSize = 1              // 保留所有簇
    }
}

