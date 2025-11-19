//
//  CollectedTagsView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/18.
//  显示所有收集到的 Vision 标签
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CollectedTagsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tagStats: [TagStat] = []
    @State private var searchText: String = ""
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    
    var filteredTagStats: [TagStat] {
        if searchText.isEmpty {
            return tagStats
        } else {
            return tagStats.filter { $0.tag.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 统计信息
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("收集到的标签")
                            .font(.headline)
                        Text("\(tagStats.count) 个唯一标签，共 \(TagCollector.shared.totalCount()) 次")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 导出按钮
                    if !tagStats.isEmpty {
                        Button(action: exportTags) {
                            Label("导出", systemImage: "square.and.arrow.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.bordered)
                        .padding(.trailing, 8)
                    }
                    
                    // 清空按钮
                    Button(action: clearTags) {
                        Label("清空", systemImage: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索标签...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 标签列表
                if filteredTagStats.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: searchText.isEmpty ? "tag.slash" : "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "暂无标签" : "未找到匹配标签")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if searchText.isEmpty {
                            Text("分析照片后，Vision 识别的标签会显示在这里")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            // 表头
                            HStack {
                                Text("标签")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("次数")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            
                            // 标签列表
                            ForEach(filteredTagStats) { tagStat in
                                TagStatRow(tagStat: tagStat)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Vision 标签库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                #if canImport(UIKit)
                ShareSheet(activityItems: [url])
                #else
                EmptyView()
                #endif
            }
        }
        .onAppear {
            loadTags()
        }
    }
    
    private func loadTags() {
        tagStats = TagCollector.shared.exportStats()
    }
    
    private func clearTags() {
        TagCollector.shared.clear()
        tagStats = []
    }
    
    // MARK: - 导出标签
    private func exportTags() {
        #if canImport(UIKit)
        // 创建文件内容
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        
        var content = "Vision 标签导出\n"
        content += "导出时间: \(dateString)\n"
        content += "唯一标签数: \(tagStats.count)\n"
        content += "总标签数: \(TagCollector.shared.totalCount())\n"
        content += "\n"
        content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        content += "\n"
        content += String(format: "%-30s %s\n", "标签", "次数")
        content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        content += "\n"
        
        // 添加所有标签（带次数）
        for tagStat in tagStats {
            content += String(format: "%-30s %d\n", tagStat.tag, tagStat.count)
        }
        
        // 创建临时文件
        let fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "vision_tags_\(fileDateFormatter.string(from: Date())).txt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            // 写入文件
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // 显示分享界面
            shareURL = fileURL
            showShareSheet = true
        } catch {
            print("❌ 导出失败: \(error.localizedDescription)")
        }
        #endif
    }
}

// MARK: - 标签统计行视图
struct TagStatRow: View {
    let tagStat: TagStat
    
    var body: some View {
        HStack {
            Image(systemName: "tag.fill")
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(tagStat.tag)
                .font(.body)
            
            Spacer()
            
            Text("\(tagStat.count)")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: 50, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

// MARK: - 分享 Sheet
#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 不需要更新
    }
}
#endif

// MARK: - 预览
#Preview {
    CollectedTagsView()
}

