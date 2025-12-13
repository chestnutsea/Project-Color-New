//
//  AnalysisSettings.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  分析设置（简化版 - 只保留默认值）
//

import Foundation

/// 颜色分析设置
class AnalysisSettings {
    
    static let shared = AnalysisSettings()
    
    // MARK: - 默认值（常量）
    
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
    
    // MARK: - 默认配置（不可修改）
    
    let effectiveColorExtractionAlgorithm: ColorExtractionAlgorithm = .labWeighted
    let effectiveExtractionQuality: ExtractionQuality = .balanced
    let effectiveAutoMergeSimilarColors: Bool = true
    let effectiveEnableAdaptiveClustering: Bool = true
    let effectiveMergeThreshold: Float = 12.0
    let effectiveUseColorNameSimilarity: Bool = true
    let effectiveMinClusterSize: Int = 2
}
