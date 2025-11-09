//
//  AnalysisHistoryView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 3: 历史分析记录查看
//

import SwiftUI
import CoreData
import Combine

struct AnalysisHistoryView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AnalysisHistoryViewModel()
    @State private var selectedSession: AnalysisSessionEntity? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("分析历史")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
        }
        .onAppear {
            viewModel.loadSessions()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无分析记录")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("完成第一次照片分析后，\n历史记录会显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Session List
    private var sessionListView: some View {
        List {
            ForEach(viewModel.sessions, id: \.id) { session in
                SessionCard(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSession = session
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteSession(session)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Session Card
struct SessionCard: View {
    
    let session: AnalysisSessionEntity
    
    private var clusters: [ColorClusterEntity] {
        (session.clusters?.allObjects as? [ColorClusterEntity])?.sorted { $0.clusterIndex < $1.clusterIndex } ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(formattedDate)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: session.status == "completed" ? "checkmark.circle.fill" : "clock.fill")
                    .foregroundColor(session.status == "completed" ? .green : .orange)
            }
            
            // Stats
            HStack(spacing: 20) {
                HistoryStatItem(icon: "photo", value: "\(session.processedCount)", label: "已处理")
                HistoryStatItem(icon: "exclamationmark.triangle", value: "\(session.failedCount)", label: "失败")
                HistoryStatItem(icon: "circle.grid.3x3", value: "\(session.optimalK)", label: "色系")
            }
            
            // Color Clusters
            if !clusters.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("色系分类")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(clusters, id: \.id) { cluster in
                                ClusterPreview(cluster: cluster)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter.string(from: session.timestamp ?? Date())
    }
}

// MARK: - History Stat Item
struct HistoryStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Cluster Preview
struct ClusterPreview: View {
    let cluster: ColorClusterEntity
    
    private var color: Color {
        Color(hex: cluster.centroidHex ?? "#CCCCCC")
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            
            Text(cluster.colorName ?? "Unknown")
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 70)
            
            Text("\(cluster.sampleCount)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Session Detail View
struct SessionDetailView: View {
    
    let session: AnalysisSessionEntity
    @Environment(\.dismiss) var dismiss
    
    private var clusters: [ColorClusterEntity] {
        (session.clusters?.allObjects as? [ColorClusterEntity])?.sorted { $0.clusterIndex < $1.clusterIndex } ?? []
    }
    
    private var photoAnalyses: [PhotoAnalysisEntity] {
        (session.photoAnalyses?.allObjects as? [PhotoAnalysisEntity]) ?? []
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Overview Section
                    overviewSection
                    
                    // Clusters Section
                    clustersSection
                }
                .padding()
            }
            .navigationTitle("分析详情")
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
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分析概览")
                .font(.headline)
            
            VStack(spacing: 8) {
                InfoRow(label: "分析时间", value: formattedDate)
                InfoRow(label: "处理照片", value: "\(session.processedCount) 张")
                InfoRow(label: "失败照片", value: "\(session.failedCount) 张")
                InfoRow(label: "识别色系", value: "\(session.optimalK) 个")
                if session.silhouetteScore > 0 {
                    InfoRow(label: "聚类质量", value: String(format: "%.3f", session.silhouetteScore))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Clusters Section
    private var clustersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("色系分类")
                .font(.headline)
            
            ForEach(clusters, id: \.id) { cluster in
                ClusterDetailCard(cluster: cluster, photoAnalyses: photoAnalyses)
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        return formatter.string(from: session.timestamp ?? Date())
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Cluster Detail Card
struct ClusterDetailCard: View {
    let cluster: ColorClusterEntity
    let photoAnalyses: [PhotoAnalysisEntity]
    
    private var color: Color {
        Color(hex: cluster.centroidHex ?? "#CCCCCC")
    }
    
    private var photosInCluster: [PhotoAnalysisEntity] {
        photoAnalyses.filter { $0.primaryClusterIndex == cluster.clusterIndex }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(cluster.colorName ?? "Unknown")
                        .font(.headline)
                    
                    Text("\(cluster.sampleCount) 张照片 · \(Int(cluster.sampleRatio * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // LAB Values
            HStack(spacing: 16) {
                LABValue(label: "L", value: cluster.centroidL)
                LABValue(label: "a", value: cluster.centroidA)
                LABValue(label: "b", value: cluster.centroidB)
            }
            .padding(.vertical, 8)
            
            // Photos Preview
            if !photosInCluster.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photosInCluster.prefix(10), id: \.id) { photoAnalysis in
                            AnalysisPhotoThumbnail(assetIdentifier: photoAnalysis.assetLocalIdentifier ?? "")
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                        }
                        
                        if photosInCluster.count > 10 {
                            Text("+\(photosInCluster.count - 10)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, height: 60)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - LAB Value
struct LABValue: View {
    let label: String
    let value: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: "%.1f", value))
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - ViewModel
class AnalysisHistoryViewModel: ObservableObject {
    
    @Published var sessions: [AnalysisSessionEntity] = []
    
    private let coreDataManager = CoreDataManager.shared
    
    func loadSessions() {
        sessions = coreDataManager.fetchAllSessions()
    }
    
    func deleteSession(_ session: AnalysisSessionEntity) {
        do {
            try coreDataManager.deleteSession(session)
            loadSessions()
        } catch {
            print("Error deleting session: \(error)")
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

