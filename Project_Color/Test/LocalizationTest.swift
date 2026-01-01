//
//  LocalizationTest.swift
//  Project_Color
//
//  多语言测试视图
//

import SwiftUI

/// 多语言测试视图 - 用于预览和测试多语言效果
struct LocalizationTestView: View {
    @State private var currentLanguage: String = "zh-Hans"
    
    var body: some View {
        NavigationView {
            List {
                Section("语言切换") {
                    Picker("当前语言", selection: $currentLanguage) {
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Tab Bar") {
                    TestRow(key: L10n.Tab.scanner)
                    TestRow(key: L10n.Tab.album)
                    TestRow(key: L10n.Tab.emerge)
                    TestRow(key: L10n.Tab.mine)
                }
                
                Section("我的页面") {
                    TestRow(key: L10n.Mine.title)
                    TestRow(key: L10n.Mine.unlockAI)
                    TestRow(key: L10n.Mine.cloudAlbum)
                    TestRow(key: L10n.Mine.photoDarkroom)
                    TestRow(key: L10n.Mine.developmentMode)
                    TestRow(key: L10n.Mine.colorLab)
                }
                
                Section("Toast 消息") {
                    TestRow(key: L10n.Toast.featureInDevelopment)
                }
                
                Section("显影模式") {
                    TestRow(key: L10n.DevelopmentMode.tone)
                    TestRow(key: L10n.DevelopmentMode.shadow)
                    TestRow(key: L10n.DevelopmentMode.comprehensive)
                }
                
                Section("扫描结果页样式") {
                    TestRow(key: L10n.ScanResultStyle.perspectiveFirst)
                    TestRow(key: L10n.ScanResultStyle.compositionFirst)
                }
            }
            .navigationTitle("多语言测试")
            .environment(\.locale, .init(identifier: currentLanguage))
        }
    }
}

/// 测试行视图
private struct TestRow: View {
    let key: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            Text(key.localized)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Previews

#Preview("中文") {
    LocalizationTestView()
        .environment(\.locale, .init(identifier: "zh-Hans"))
}

#Preview("English") {
    LocalizationTestView()
        .environment(\.locale, .init(identifier: "en"))
}

#Preview("KitView - 中文") {
    KitView()
        .environment(\.locale, .init(identifier: "zh-Hans"))
}

#Preview("KitView - English") {
    KitView()
        .environment(\.locale, .init(identifier: "en"))
}


