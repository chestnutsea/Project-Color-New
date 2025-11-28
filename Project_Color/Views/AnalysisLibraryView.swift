//
//  AnalysisLibraryView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/23.
//  分析结果库：显示所有分析结果（收藏/全部）
//

import SwiftUI
import Photos
import CoreData
import Combine

/// 分析结果信息
struct AnalysisSessionInfo: Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let photoCount: Int
    let isFavorite: Bool
    var coverAssetIdentifier: String?  // 最新照片的 assetLocalIdentifier
}

struct AnalysisLibraryView: View {
    @StateObject private var viewModel = AnalysisLibraryViewModel()
    @State private var selectedTab: LibraryTab = .favorites
    @State private var selectedSession: AnalysisSessionInfo?
    @State private var sessionToDelete: AnalysisSessionInfo?
    @State private var showDeleteAlert = false
    @State private var sessionToEdit: AnalysisSessionInfo?
    @State private var showEditSheet = false
    
    enum LibraryTab: String, CaseIterable {
        case favorites = "收藏"
        case all = "素材"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab 选择器 - 紧贴导航栏
                Picker("", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // 内容区域
                if filteredSessions.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    sessionGridView
                }
            }
            .navigationTitle("相册")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            viewModel.loadSessions()
        }
        .sheet(item: $selectedSession) { sessionInfo in
            // 显示分析结果详情
            AnalysisResultSheetView(
                sessionInfo: sessionInfo,
                viewModel: viewModel,
                onDismiss: {
                    selectedSession = nil
                }
            )
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                sessionToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
                sessionToDelete = nil
            }
        } message: {
            Text("确定要删除这个分析结果吗？此操作无法撤销。")
        }
        .sheet(isPresented: $showEditSheet) {
            if let session = sessionToEdit {
                SessionEditSheet(
                    session: session,
                    onSave: { name, date in
                        updateSessionInfo(session, name: name, date: date)
                        sessionToEdit = nil
                        showEditSheet = false
                    },
                    onCancel: {
                        sessionToEdit = nil
                        showEditSheet = false
                    }
                )
            }
        }
    }
    
    // 根据选中的 tab 过滤会话
    private var filteredSessions: [AnalysisSessionInfo] {
        switch selectedTab {
        case .favorites:
            return viewModel.sessions.filter { $0.isFavorite }
        case .all:
            // 素材 tab 只显示未收藏的
            return viewModel.sessions.filter { !$0.isFavorite }
        }
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedTab == .favorites ? "heart" : "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(selectedTab == .favorites ? "暂无收藏" : "暂无素材")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text(selectedTab == .favorites ? 
                 "点击分析结果页的爱心图标\n即可收藏" : 
                 "分析照片后素材会显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - 分析结果网格
    private var sessionGridView: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 16
            let padding: CGFloat = 16
            let availableWidth = geometry.size.width - (padding * 2) - spacing
            let cardSize = availableWidth / 2
            
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(cardSize), spacing: spacing),
                        GridItem(.fixed(cardSize), spacing: spacing)
                    ],
                    spacing: spacing
                ) {
                    ForEach(filteredSessions) { session in
                        LibrarySessionCard(
                            session: session,
                            cardSize: cardSize,
                            onFavorite: {
                                toggleFavorite(session)
                            },
                            onEdit: {
                                sessionToEdit = session
                                showEditSheet = true
                            },
                            onDelete: {
                                sessionToDelete = session
                                showDeleteAlert = true
                            }
                        )
                        .onTapGesture {
                            selectedSession = session
                        }
                    }
                }
                .padding(padding)
            }
        }
    }
    
    // MARK: - 操作方法
    
    /// 切换收藏状态
    private func toggleFavorite(_ session: AnalysisSessionInfo) {
        let newStatus = !session.isFavorite
        print("🔄 toggleFavorite 被调用")
        print("   - Session: \(session.name)")
        print("   - 当前状态: \(session.isFavorite ? "已收藏" : "未收藏")")
        print("   - 新状态: \(newStatus ? "已收藏" : "未收藏")")
        
        do {
            try CoreDataManager.shared.updateSessionFavoriteStatus(sessionId: session.id, isFavorite: newStatus)
            print("✅ Core Data 更新成功")
            
            // 重新加载数据
            viewModel.loadSessions()
            print("✅ 数据已重新加载")
        } catch {
            print("❌ 更新收藏状态失败: \(error)")
        }
    }
    
    /// 更新分析会话信息（名称和日期）
    private func updateSessionInfo(_ session: AnalysisSessionInfo, name: String, date: Date) {
        print("✏️ updateSessionInfo 被调用")
        print("   - Session: \(session.name) → \(name)")
        print("   - Date: \(date)")
        
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<AnalysisSessionEntity> = AnalysisSessionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            if let entity = try context.fetch(fetchRequest).first {
                entity.customName = name
                entity.customDate = date
                try context.save()
                print("✅ 更新成功")
                
                // 重新加载数据
                viewModel.loadSessions()
            }
        } catch {
            print("❌ 更新会话信息失败: \(error)")
        }
    }
    
    /// 删除分析会话
    private func deleteSession(_ session: AnalysisSessionInfo) {
        print("🗑️ deleteSession 被调用")
        print("   - Session: \(session.name)")
        print("   - ID: \(session.id)")
        
        let context = CoreDataManager.shared.container.viewContext
        
        // 查找并删除会话
        let fetchRequest: NSFetchRequest<AnalysisSessionEntity> = AnalysisSessionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            print("   - 找到 \(results.count) 个匹配的实体")
            
            if let entity = results.first {
                context.delete(entity)
                try context.save()
                print("✅ 删除成功")
                
                // 重新加载数据
                viewModel.loadSessions()
                print("✅ 数据已重新加载")
            } else {
                print("⚠️ 未找到要删除的实体")
            }
        } catch {
            print("❌ 删除会话失败: \(error)")
        }
    }
}

// MARK: - 分析结果 Sheet 视图（带导航栏）
struct AnalysisResultSheetView: View {
    let sessionInfo: AnalysisSessionInfo
    @ObservedObject var viewModel: AnalysisLibraryViewModel
    let onDismiss: () -> Void
    
    @State private var analysisResult: AnalysisResult?
    
    var body: some View {
        Group {
            if let result = analysisResult {
                // 使用 AnalysisResultView，设置为 Sheet 模式（只改变返回按钮样式）
                AnalysisResultView(
                    result: result,
                    onDismiss: onDismiss,
                    isSheetMode: true
                )
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("加载中...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadAnalysisResult()
        }
    }
    
    private func loadAnalysisResult() async {
        if let result = await viewModel.loadAnalysisResultAsync(for: sessionInfo.id) {
            await MainActor.run {
                analysisResult = result
            }
        }
    }
}

// MARK: - 分析结果卡片
struct LibrarySessionCard: View {
    let session: AnalysisSessionInfo
    let cardSize: CGFloat
    let onFavorite: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var coverImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面图（正方形）
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: cardSize, height: cardSize)
            .clipped()
            .cornerRadius(12)
            .contextMenu {
                Button(action: onFavorite) {
                    Label(
                        session.isFavorite ? "移除收藏" : "收藏",
                        systemImage: session.isFavorite ? "heart.fill" : "heart"
                    )
                }
                
                Button(action: onEdit) {
                    Label("编辑信息", systemImage: "square.and.pencil")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            }
            
            // 名称
            Text(session.name)
                .font(.headline)
                .lineLimit(1)
                .frame(width: cardSize, alignment: .leading)
            
            // 日期和照片数量
            HStack {
                Text(formatDate(session.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(session.photoCount) 张")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: cardSize)
        }
        .onAppear {
            loadCoverImage()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
    
    private func loadCoverImage() {
        guard let assetId = session.coverAssetIdentifier else { return }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.coverImage = image
                }
            }
        }
    }
}

// MARK: - ViewModel
class AnalysisLibraryViewModel: ObservableObject {
    @Published var sessions: [AnalysisSessionInfo] = []
    @Published var isLoading = false
    
    private let coreDataManager = CoreDataManager.shared
    
    func loadSessions() {
        // 在后台线程执行 Core Data 查询
        Task.detached(priority: .userInitiated) { [coreDataManager] in
            let context = coreDataManager.newBackgroundContext()
            var sessionInfos: [AnalysisSessionInfo] = []
            
            context.performAndWait {
                let request: NSFetchRequest<AnalysisSessionEntity> = AnalysisSessionEntity.fetchRequest()
                
                // 按日期降序排序
                request.sortDescriptors = [
                    NSSortDescriptor(key: "customDate", ascending: false),
                    NSSortDescriptor(key: "timestamp", ascending: false)
                ]
                
                do {
                    let entities = try context.fetch(request)
                    print("📊 查询到 \(entities.count) 个分析会话")
                    
                    sessionInfos = entities.compactMap { entity -> AnalysisSessionInfo? in
                        guard let id = entity.id else { return nil }
                        
                        let name = entity.customName ?? "未命名"
                        let date = entity.customDate ?? entity.timestamp ?? Date()
                        let photoCount = Int(entity.totalPhotoCount)
                        let isFavorite = entity.isFavorite
                        
                        // 获取第一张照片作为封面
                        // 直接从 photoAnalyses 关系中获取，避免加载完整的分析结果
                        let photoAnalyses = entity.photoAnalyses as? Set<PhotoAnalysisEntity>
                        let coverAssetId = photoAnalyses?.first?.assetLocalIdentifier
                        
                        return AnalysisSessionInfo(
                            id: id,
                            name: name,
                            date: date,
                            photoCount: photoCount,
                            isFavorite: isFavorite,
                            coverAssetIdentifier: coverAssetId
                        )
                    }
                } catch {
                    print("❌ 加载分析会话失败: \(error.localizedDescription)")
                }
            }
            
            // 更新 UI（在主线程）
            await MainActor.run {
                self.sessions = sessionInfos
                print("✅ 加载了 \(sessionInfos.count) 个分析会话")
                print("   - 收藏: \(sessionInfos.filter { $0.isFavorite }.count)")
                print("   - 素材: \(sessionInfos.filter { !$0.isFavorite }.count)")
            }
        }
    }
    
    /// 从 Core Data 加载完整的分析结果（异步版本，在后台线程执行）
    func loadAnalysisResultAsync(for sessionId: UUID) async -> AnalysisResult? {
        return await Task.detached(priority: .userInitiated) { [coreDataManager] in
            return AnalysisLibraryViewModel.loadAnalysisResultBackground(
                sessionId: sessionId,
                coreDataManager: coreDataManager
            )
        }.value
    }
    
    /// 从 Core Data 加载完整的分析结果（后台线程版本）
    private static func loadAnalysisResultBackground(
        sessionId: UUID,
        coreDataManager: CoreDataManager
    ) -> AnalysisResult? {
        let context = coreDataManager.newBackgroundContext()
        var result: AnalysisResult?
        
        context.performAndWait {
            let request: NSFetchRequest<AnalysisSessionEntity> = AnalysisSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
            request.fetchLimit = 1
            
            do {
                guard let entity = try context.fetch(request).first else {
                    print("❌ 未找到会话: \(sessionId)")
                    return
                }
                
                // 将 AnalysisSessionEntity 转换为 AnalysisResult
                let analysisResult = AnalysisResult()
                analysisResult.sessionId = entity.id
                analysisResult.timestamp = entity.timestamp ?? Date()
                
                analysisResult.totalPhotoCount = Int(entity.totalPhotoCount)
                analysisResult.processedCount = Int(entity.processedCount)
                analysisResult.failedCount = Int(entity.failedCount)
                analysisResult.optimalK = Int(entity.optimalK)
                analysisResult.silhouetteScore = entity.silhouetteScore
                analysisResult.isCompleted = entity.status == "completed"
                
                // 加载用户输入的感受
                if let userMessage = entity.userMessage, !userMessage.isEmpty {
                    analysisResult.userMessage = userMessage
                    print("✅ 加载用户感受: \(userMessage)")
                } else {
                    print("ℹ️ 该分析结果没有用户感受")
                }
                
                // 加载聚类信息
                if let clusterEntities = entity.clusters?.allObjects as? [ColorClusterEntity] {
                    analysisResult.clusters = clusterEntities.sorted { $0.clusterIndex < $1.clusterIndex }.map { clusterEntity in
                        let centroid = SIMD3<Float>(
                            clusterEntity.centroidR,
                            clusterEntity.centroidG,
                            clusterEntity.centroidB_RGB
                        )
                        return ColorCluster(
                            index: Int(clusterEntity.clusterIndex),
                            centroid: centroid,
                            colorName: clusterEntity.colorName ?? "未命名",
                            photoCount: Int(clusterEntity.sampleCount)
                        )
                    }
                }
                
                // 加载照片信息
                if let photoEntities = entity.photoAnalyses?.allObjects as? [PhotoAnalysisEntity] {
                    analysisResult.photoInfos = photoEntities.map { photoEntity in
                        var photoInfo = PhotoColorInfo(assetIdentifier: photoEntity.assetLocalIdentifier ?? "")
                        photoInfo.albumIdentifier = photoEntity.albumIdentifier
                        photoInfo.albumName = photoEntity.albumName
                        photoInfo.primaryClusterIndex = Int(photoEntity.primaryClusterIndex)
                        
                        // 加载主色信息
                        if let dominantColorsData = photoEntity.dominantColors,
                           let dominantColors = try? JSONDecoder().decode([DominantColor].self, from: dominantColorsData) {
                            photoInfo.dominantColors = dominantColors
                        }
                        
                        // 加载 CDF 数据
                        if let cdfData = photoEntity.brightnessCDF {
                            let cdfArray = cdfData.withUnsafeBytes { buffer in
                                Array(buffer.bindMemory(to: Float.self))
                            }
                            photoInfo.brightnessCDF = cdfArray
                        }
                        
                        // 加载高级色彩分析
                        if let advancedData = photoEntity.advancedColorAnalysisData,
                           let advancedAnalysis = try? JSONDecoder().decode(AdvancedColorAnalysis.self, from: advancedData) {
                            photoInfo.advancedColorAnalysis = advancedAnalysis
                        }
                        
                        return photoInfo
                    }
                }
                
                // 加载 AI 评价
                if let aiEvaluationData = entity.aiEvaluationData {
                    if var aiEvaluation = try? JSONDecoder().decode(ColorEvaluation.self, from: aiEvaluationData) {
                        aiEvaluation.isLoading = false
                        analysisResult.aiEvaluation = aiEvaluation
                    }
                }
                
                // 重新计算温度分布
                if !analysisResult.photoInfos.isEmpty {
                    var scores: [String: AdvancedColorAnalysis] = [:]
                    for photoInfo in analysisResult.photoInfos {
                        if let advanced = photoInfo.advancedColorAnalysis {
                            scores[photoInfo.assetIdentifier] = advanced
                        }
                    }
                    
                    if !scores.isEmpty {
                        let allScores = scores.values.map { $0.overallScore }
                        let minScore = allScores.min() ?? -1.0
                        let maxScore = allScores.max() ?? 1.0
                        let bins = 20
                        var histogram = [Float](repeating: 0, count: bins)
                        
                        let scoreRange = maxScore - minScore
                        if scoreRange > 0.001 {
                            for score in allScores {
                                let normalizedScore = (score - minScore) / scoreRange
                                if normalizedScore.isFinite {
                                    let binIndex = min(max(Int(normalizedScore * Float(bins)), 0), bins - 1)
                                    histogram[binIndex] += 1
                                }
                            }
                        } else {
                            histogram[bins / 2] = Float(allScores.count)
                        }
                        
                        analysisResult.warmCoolDistribution = WarmCoolDistribution(
                            scores: scores,
                            histogram: histogram,
                            histogramBins: bins,
                            minScore: minScore,
                            maxScore: maxScore
                        )
                    }
                }
                
                // 统计加载的数据
                let photosWithCDF = analysisResult.photoInfos.filter { $0.brightnessCDF != nil }.count
                let photosWithAdvanced = analysisResult.photoInfos.filter { $0.advancedColorAnalysis != nil }.count
                
                print("✅ 成功加载分析结果: \(entity.customName ?? "未命名")")
                print("   - 聚类数: \(analysisResult.clusters.count)")
                print("   - 照片数: \(analysisResult.photoInfos.count)")
                print("   - 有 CDF 的照片: \(photosWithCDF)")
                print("   - 有高级分析的照片: \(photosWithAdvanced)")
                print("   - 有 AI 评价: \(analysisResult.aiEvaluation != nil)")
                print("   - 有温度分布: \(analysisResult.warmCoolDistribution != nil)")
                
                result = analysisResult
                
            } catch {
                print("❌ 加载分析结果失败: \(error.localizedDescription)")
            }
        }
        
        return result
    }
}

// MARK: - 编辑照片集信息 Sheet
struct SessionEditSheet: View {
    let session: AnalysisSessionInfo
    let onSave: (String, Date) -> Void
    let onCancel: () -> Void
    
    @State private var sessionName: String
    @State private var sessionDate: Date
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFieldFocused: Bool
    
    init(session: AnalysisSessionInfo, onSave: @escaping (String, Date) -> Void, onCancel: @escaping () -> Void) {
        self.session = session
        self.onSave = onSave
        self.onCancel = onCancel
        
        _sessionName = State(initialValue: session.name)
        _sessionDate = State(initialValue: session.date)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("名称", text: $sessionName)
                        .textInputAutocapitalization(.words)
                        .focused($isNameFieldFocused)
                    
                    DatePicker("日期", selection: $sessionDate, displayedComponents: .date)
                }
            }
            .navigationTitle("编辑信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(sessionName.trimmingCharacters(in: .whitespacesAndNewlines), sessionDate)
                        dismiss()
                    }
                    .disabled(sessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFieldFocused = true
                }
            }
        }
    }
}

#Preview {
    AnalysisLibraryView()
}

