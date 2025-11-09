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
    
    var body: some View {
        NavigationView {
            Form {
                // 预设配置
                Section {
                    Button("精细分类（更多簇）") {
                        settings.applyFineGrainedPreset()
                    }
                    Button("平衡分类（推荐）") {
                        settings.applyBalancedPreset()
                    }
                    Button("简洁分类（更少簇）") {
                        settings.applySimplifiedPreset()
                    }
                } header: {
                    Text("预设配置")
                } footer: {
                    Text("快速应用预设配置，或在下方自定义")
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
                    Text("开启时，只合并名称相似的簇（如 DarkBlue + LightBlue）。关闭时，仅根据色差合并。")
                }
                
                // 当前配置
                Section {
                    Text(settings.configurationDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("当前配置")
                }
                
                // 重置按钮
                Section {
                    Button("重置所有设置") {
                        settings.resetToDefaults()
                    }
                    .foregroundColor(.red)
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
}

#Preview {
    AnalysisSettingsView()
}

