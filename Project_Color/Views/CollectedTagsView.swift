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
    @State private var tagStatsBySource: [TagSource: [TagStat]] = [:]
    @State private var selectedSource: TagSource = .sceneClassification
    @State private var searchText: String = ""
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showClearAlert = false
    
    var currentTagStats: [TagStat] {
        tagStatsBySource[selectedSource] ?? []
    }
    
    var filteredTagStats: [TagStat] {
        if searchText.isEmpty {
            return currentTagStats
        } else {
            return currentTagStats.filter { $0.tag.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var totalTagCount: Int {
        tagStatsBySource.values.flatMap { $0 }.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 统计信息
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("收集到的标签")
                            .font(.headline)
                        Text("\(totalTagCount) 个标签，共 \(TagCollector.shared.totalCount()) 次")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 导出按钮
                    if totalTagCount > 0 {
                        Button(action: exportTags) {
                            Label("导出", systemImage: "square.and.arrow.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.bordered)
                        .padding(.trailing, 8)
                    }
                    
                    // 清空按钮
                    Button(action: { showClearAlert = true }) {
                        Label("清空", systemImage: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Tab 选择器（移除了"图像"，因为与"场景"重复）
                Picker("来源", selection: $selectedSource) {
                    Text("场景").tag(TagSource.sceneClassification)
                    Text("对象").tag(TagSource.objectRecognition)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
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
                            HStack(spacing: 8) {
                                Text("标签")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Text("次数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .center)
                                Text("均值")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .center)
                                Text("最大")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .center)
                                Text("最小")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .center)
                                Text("方差")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .center)
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
        .alert("清空 Vision 标签", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                clearTags()
            }
        } message: {
            Text("确定要清空所有 Vision 标签吗？此操作会同时清空内存和 Core Data 中的标签数据，不可恢复。")
        }
        .onAppear {
            loadTags()
        }
    }
    
    private func loadTags() {
        tagStatsBySource = TagCollector.shared.exportStatsBySource()
    }
    
    private func clearTags() {
        // 清空内存中的标签
        TagCollector.shared.clear()
        
        // 清空 Core Data 中的标签
        let count = CoreDataManager.shared.clearAllVisionTags()
        print("✅ 已清空 \(count) 个 Vision 标签（Core Data）")
        
        // 刷新显示
        tagStatsBySource = [:]
    }
    
    // MARK: - 导出标签
    private func exportTags() {
        #if canImport(UIKit)
        Task.detached(priority: .userInitiated) {
            let tagData = await MainActor.run { tagStatsBySource }
            
            // 构建 CSV，包含 tag、count、source、mean、max、min、variance
            var rows: [String] = ["tag,count,source,mean,max,min,variance"]
            for source in [TagSource.sceneClassification, TagSource.objectRecognition] {
                guard let stats = tagData[source], !stats.isEmpty else { continue }
                for stat in stats {
                    let sanitizedTag = stat.tag.replacingOccurrences(of: ",", with: " ")
                    let mean = String(format: "%.4f", stat.confidenceMean)
                    let max = String(format: "%.4f", stat.confidenceMax)
                    let min = String(format: "%.4f", stat.confidenceMin)
                    let variance = String(format: "%.6f", stat.confidenceVariance)
                    rows.append("\(sanitizedTag),\(stat.count),\(source.rawValue),\(mean),\(max),\(min),\(variance)")
                }
            }
            
            let content = rows.joined(separator: "\n")
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("vision_tags_\(formatter.string(from: Date())).csv")
            
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                await MainActor.run {
                    shareURL = fileURL
                    showShareSheet = true
                }
                print("✅ 标签导出成功: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ 导出失败: \(error.localizedDescription)")
            }
        }
        #endif
    }
}

// MARK: - 标签统计行视图
struct TagStatRow: View {
    let tagStat: TagStat
    
    private var sourceIcon: String {
        switch tagStat.source {
        case .sceneClassification:
            return "photo.on.rectangle"
        case .imageClassification:
            return "photo"
        case .objectRecognition:
            return "cube.box"
        }
    }
    
    private var sourceColor: Color {
        switch tagStat.source {
        case .sceneClassification:
            return .blue
        case .imageClassification:
            return .green
        case .objectRecognition:
            return .orange
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(tagStat.tag)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)
            
            Text("\(tagStat.count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .center)
            
            Text(String(format: "%.3f", tagStat.confidenceMean))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .center)
            
            Text(String(format: "%.3f", tagStat.confidenceMax))
                .font(.caption)
                .foregroundColor(.green)
                .frame(width: 50, alignment: .center)
            
            Text(String(format: "%.3f", tagStat.confidenceMin))
                .font(.caption)
                .foregroundColor(.orange)
                .frame(width: 50, alignment: .center)
            
            Text(String(format: "%.4f", tagStat.confidenceVariance))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .center)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
