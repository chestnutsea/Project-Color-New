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
    
    // MARK: - 自适应聚类设置
    
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
    
    private let defaultMergeThreshold: Float = 12.0
    private let defaultUseColorNameSimilarity: Bool = true
    private let defaultMinClusterSize: Int = 2
    
    // MARK: - 获取实际使用的值
    
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
}

