//
//  AnalysisResultView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 1: 分析结果展示页面
//

import SwiftUI
import Photos

struct AnalysisResultView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var result: AnalysisResult
    @State private var selectedCluster: ColorCluster?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 头部统计信息
                    headerSection
                    
                    // Phase 4: 聚类质量指标
                    qualitySection
                    
                    // 聚类结果
                    clustersSection
                    
                    // 底部统计
                    if result.failedCount > 0 {
                        failedSection
                    }
                    
                    Spacer(minLength: 20)
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
                    ClusterCard(cluster: cluster)
                        .onTapGesture {
                            selectedCluster = cluster
                        }
                }
            }
        }
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
    
    var body: some View {
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
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
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
        result.photos(in: cluster.index)
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

