//
//  AnalysisSettingsView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  颜色分析设置界面
//

import SwiftUI

struct AnalysisSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = AnalysisSettings.shared
    @State private var showClearCacheAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // 预设配置
                Section {
                    Button("平衡分类（推荐）") {
                        settings.applyBalancedPreset()
                    }
                    Button("多彩模式（丰富色彩）") {
                        settings.applyColorfulPreset()
                    }
                    Button("单色系细分（同色系照片）") {
                        settings.applyMonochromePreset()
                    }
                    Button("精细分类（更多簇）") {
                        settings.applyFineGrainedPreset()
                    }
                    Button("简洁分类（更少簇）") {
                        settings.applySimplifiedPreset()
                    }
                } header: {
                    Text("预设配置")
                } footer: {
                    Text("快速应用预设配置，或在下方自定义。\n• 多彩模式：保留更多色系，适合颜色丰富的照片（如旅行、聚会）\n• 单色系细分：细分相似色，适合颜色相近的照片（如全绿色、全蓝色）")
                }
                
                // 合并阈值
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("合并阈值 (ΔE₀₀)")
                            Spacer()
                            Text(String(format: "%.1f", settings.effectiveMergeThreshold))
                                .foregroundColor(.blue)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(settings.mergeThresholdDeltaE ?? 12.0) },
                                set: { settings.mergeThresholdDeltaE = Float($0) }
                            ),
                            in: 5.0...25.0,
                            step: 1.0
                        )
                        
                        Text(thresholdDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if settings.mergeThresholdDeltaE != nil {
                        Button("使用默认值 (12.0)") {
                            settings.mergeThresholdDeltaE = nil
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("色差合并阈值")
                } footer: {
                    Text("控制颜色合并的严格程度。值越小，簇越多；值越大，簇越少。")
                }
                
                // 最小簇大小
                Section {
                    Picker("最小簇大小", selection: Binding(
                        get: { settings.minClusterSize ?? 2 },
                        set: { settings.minClusterSize = $0 }
                    )) {
                        Text("1 张（保留所有）").tag(1)
                        Text("2 张（推荐）").tag(2)
                        Text("3 张").tag(3)
                        Text("5 张").tag(5)
                    }
                    
                    if settings.minClusterSize != nil {
                        Button("使用默认值 (2)") {
                            settings.minClusterSize = nil
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("最小簇大小")
                } footer: {
                    Text("照片数少于此值的簇会被删除。设为1可保留所有簇。")
                }
                
                // 手动指定 K 值
                Section {
                    Toggle("手动指定色系数量", isOn: Binding(
                        get: { settings.manualKValue != nil },
                        set: { newValue in
                            if newValue {
                                settings.manualKValue = 8  // 默认 8
                            } else {
                                settings.manualKValue = nil
                            }
                        }
                    ))
                    
                    if let _ = settings.manualKValue {
                        Stepper("色系数量: \(settings.manualKValue ?? 8)", value: Binding(
                            get: { settings.manualKValue ?? 8 },
                            set: { settings.manualKValue = $0 }
                        ), in: 3...12)
                        
                        Text("当前: \(settings.manualKValue ?? 8) 个色系")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("全局聚类")
                } footer: {
                    if settings.manualKValue != nil {
                        Text("已手动指定 K=\(settings.manualKValue!)，将跳过自动选择。适合单色系照片细分。")
                    } else {
                        Text("自动选择最优色系数量（K值），基于 Silhouette Score 评估。")
                    }
                }
                
                // 自适应聚类开关
                Section {
                    Toggle("启用自适应聚类", isOn: Binding(
                        get: { settings.enableAdaptiveClustering ?? true },
                        set: { settings.enableAdaptiveClustering = $0 }
                    ))
                    
                    if settings.enableAdaptiveClustering != nil {
                        Button("使用默认值 (开启)") {
                            settings.enableAdaptiveClustering = nil
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("自适应聚类")
                } footer: {
                    Text("关闭后，将保留全局聚类的原始结果（K个簇），不进行合并/删除操作。适合单色系照片细分。")
                }
                
                // 颜色名称相似性
                Section {
                    Toggle("启用颜色名称相似性", isOn: Binding(
                        get: { settings.useColorNameSimilarity ?? true },
                        set: { settings.useColorNameSimilarity = $0 }
                    ))
                    
                    if settings.useColorNameSimilarity != nil {
                        Button("使用默认值 (开启)") {
                            settings.useColorNameSimilarity = nil
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("智能合并")
                } footer: {
                    Text("开启时，只合并名称相似的簇（如 DarkBlue + LightBlue）。关闭时，仅根据色差合并。仅在启用自适应聚类时生效。")
                }
                
                // 当前配置
                Section {
                    Text(settings.configurationDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("当前配置")
                }
                
                // 单图主色提取设置
                Section {
                    Picker("主色提取算法", selection: Binding(
                        get: { settings.colorExtractionAlgorithm ?? .labWeighted },
                        set: { settings.colorExtractionAlgorithm = $0 }
                    )) {
                        Text("🎨 感知模式（推荐）").tag(AnalysisSettings.ColorExtractionAlgorithm.labWeighted)
                        Text("⚡ 快速模式").tag(AnalysisSettings.ColorExtractionAlgorithm.medianCut)
                    }
                    
                    Picker("处理精度", selection: Binding(
                        get: { settings.extractionQuality ?? .balanced },
                        set: { settings.extractionQuality = $0 }
                    )) {
                        Text("快速").tag(AnalysisSettings.ExtractionQuality.fast)
                        Text("平衡（推荐）").tag(AnalysisSettings.ExtractionQuality.balanced)
                        Text("精细").tag(AnalysisSettings.ExtractionQuality.fine)
                    }
                    
                    Toggle("自动合并相似色", isOn: Binding(
                        get: { settings.autoMergeSimilarColors ?? true },
                        set: { settings.autoMergeSimilarColors = $0 }
                    ))
                    
                    if settings.colorExtractionAlgorithm != nil || 
                       settings.extractionQuality != nil || 
                       settings.autoMergeSimilarColors != nil {
                        Button("恢复默认") {
                            settings.colorExtractionAlgorithm = nil
                            settings.extractionQuality = nil
                            settings.autoMergeSimilarColors = nil
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("单图主色提取")
                } footer: {
                    Text(extractionDescription)
                }
                
                // 重置按钮
                Section {
                    Button("重置所有设置") {
                        settings.resetToDefaults()
                    }
                    .foregroundColor(.red)
                } footer: {
                    Text("重置为推荐的默认配置")
                }
                
                // 缓存管理
                Section {
                    Button("清除颜色分析缓存") {
                        showClearCacheAlert = true
                    }
                    .foregroundColor(.orange)
                } header: {
                    Text("缓存管理")
                } footer: {
                    Text("清除后，下次分析会重新提取所有照片的颜色。注意：缓存只存储颜色提取结果，不影响聚类设置的应用。")
                }
            }
            .navigationTitle("分析设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("清除缓存", isPresented: $showClearCacheAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("确定要清除所有颜色分析缓存吗？下次分析将重新提取照片颜色。")
            }
        }
    }
    
    // MARK: - Helper
    
    private var thresholdDescription: String {
        let value = settings.effectiveMergeThreshold
        
        if value < 8 {
            return "非常严格 - 保留更多细微差异"
        } else if value < 12 {
            return "严格 - 只合并非常相似的颜色"
        } else if value < 16 {
            return "适中 - 平衡合并与保留"
        } else if value < 20 {
            return "宽松 - 合并相近的颜色"
        } else {
            return "非常宽松 - 大幅简化分类"
        }
    }
    
    private var extractionDescription: String {
        let algorithm = settings.effectiveColorExtractionAlgorithm
        let quality = settings.effectiveExtractionQuality
        
        var desc = ""
        if algorithm == .labWeighted {
            desc = "感知模式使用 Lab 色彩空间，更符合人眼感知，提取自然、真实的主色层次。"
        } else {
            desc = "快速模式速度更快，适合霓虹、展览、集市等高对比场景。"
        }
        
        desc += "\n"
        switch quality {
        case .fast:
            desc += "快速精度：约 20ms/张。"
        case .balanced:
            desc += "平衡精度：约 80ms/张（推荐）。"
        case .fine:
            desc += "精细精度：约 133ms/张，最高质量。"
        }
        
        return desc
    }
    
    private func clearCache() {
        let cache = PhotoColorCache()
        cache.clearAllCache()
        print("✅ 已清除所有颜色分析缓存")
    }
}

#Preview {
    AnalysisSettingsView()
}

