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

// MARK: - 通知名称
extension Notification.Name {
    static let analysisSessionDidSave = Notification.Name("analysisSessionDidSave")
}

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
    @State private var showEditOverlay = false
    
    enum LibraryTab: String, CaseIterable {
        case favorites = "收藏"
        case all = "素材"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 自定义标题
                Text("相册")
                    .font(.system(size: AppStyle.tabTitleFontSize, weight: AppStyle.tabTitleFontWeight))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, AppStyle.tabTitleTopPadding)
                    .padding(.bottom, 8)
                
                // Tab 选择器
                Picker("", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                // 内容区域（支持左右滑动切换）
                TabView(selection: $selectedTab) {
                    // 收藏页
                    tabContentView(for: .favorites)
                        .tag(LibraryTab.favorites)
                    
                    // 素材页
                    tabContentView(for: .all)
                        .tag(LibraryTab.all)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadSessions()
            // ✅ 优化：预加载最近的分析结果，避免首次点击时等待
            viewModel.preloadRecentResults()
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisSessionDidSave)) { _ in
            // 收到新分析保存通知，强制刷新数据
            viewModel.forceRefresh()
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
        .overlay(alignment: .center) {
            if showEditOverlay, let session = sessionToEdit {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showEditOverlay = false
                            sessionToEdit = nil
                        }
                    
                    SessionEditAlertView(
                        session: session,
                        onConfirm: { name, date in
                            updateSessionInfo(session, name: name, date: date)
                            sessionToEdit = nil
                            showEditOverlay = false
                        },
                        onCancel: {
                            sessionToEdit = nil
                            showEditOverlay = false
                        }
                    )
                    .frame(width: 320)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 20)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
                }
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showEditOverlay)
    }
    
    // 根据 tab 过滤会话
    private func sessionsForTab(_ tab: LibraryTab) -> [AnalysisSessionInfo] {
        switch tab {
        case .favorites:
            return viewModel.sessions.filter { $0.isFavorite }
        case .all:
            // 素材 tab 只显示未收藏的
            return viewModel.sessions.filter { !$0.isFavorite }
        }
    }
    
    // 根据选中的 tab 过滤会话（兼容旧代码）
    private var filteredSessions: [AnalysisSessionInfo] {
        sessionsForTab(selectedTab)
    }
    
    // MARK: - Tab 内容视图
    @ViewBuilder
    private func tabContentView(for tab: LibraryTab) -> some View {
        let sessions = sessionsForTab(tab)
        
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if sessions.isEmpty {
            emptyStateView(for: tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            sessionGridView(for: sessions)
        }
    }
    
    // MARK: - 空状态
    private func emptyStateView(for tab: LibraryTab) -> some View {
        VStack(spacing: 20) {
            Image(systemName: tab == .favorites ? "heart" : "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text(tab == .favorites ? "暂无收藏" : "暂无素材")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
    
    // 兼容旧代码
    private var emptyStateView: some View {
        emptyStateView(for: selectedTab)
    }
    
    // MARK: - 分析结果网格
    private func sessionGridView(for sessions: [AnalysisSessionInfo]) -> some View {
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
                    ForEach(sessions) { session in
                        LibrarySessionCard(
                            session: session,
                            cardSize: cardSize,
                            onFavorite: {
                                toggleFavorite(session)
                            },
                            onEdit: {
                                sessionToEdit = session
                                showEditOverlay = true
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
    
    // 兼容旧代码
    private var sessionGridView: some View {
        sessionGridView(for: filteredSessions)
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
            
            // ✅ 强制刷新数据（而不是 loadSessions，因为后者有缓存检查）
            viewModel.forceRefresh()
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
                
                // ✅ 强制刷新数据
                viewModel.forceRefresh()
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
                
                // ✅ 清除该会话的缓存
                AnalysisResultCache.shared.removeResult(for: session.id)
                print("✅ 已清除缓存")
                
                // ✅ 强制刷新数据
                viewModel.forceRefresh()
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
        .onAppear {
            // ✅ 优化：先同步检查缓存，如果有缓存就直接显示（瞬间打开）
            if let cachedResult = AnalysisResultCache.shared.result(for: sessionInfo.id) {
                analysisResult = cachedResult
                print("📦 分析结果缓存命中（同步）: \(sessionInfo.id)")
            }
        }
        .task {
            // 如果缓存未命中，才异步加载
            if analysisResult == nil {
                await loadAnalysisResult()
            }
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
        
        // ✅ 优化：先检查缓存
        if let cachedImage = ThumbnailCache.shared.image(for: assetId) {
            self.coverImage = cachedImage
            return
        }
        
        // ✅ 优化：缓存未命中，使用异步加载，避免阻塞
        Task {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else { return }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat  // ✅ 使用 highQualityFormat 确保只回调一次
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false
            
            // ✅ 修复：使用 actor 隔离来防止重复 resume
            let loadedImage: UIImage? = await withCheckedContinuation { continuation in
                var hasResumed = false
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 300, height: 300),
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    // ✅ 防止重复 resume（即使 highQualityFormat 也可能在某些情况下多次回调）
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
            
            if let image = loadedImage {
                // 存入缓存
                ThumbnailCache.shared.setImage(image, for: assetId)
                await MainActor.run {
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
    private var hasLoadedOnce = false  // ✅ 避免重复加载
    
    /// 加载会话列表（如果已加载过则跳过）
    func loadSessions() {
        // ✅ 如果已经加载过且有数据，直接返回
        if hasLoadedOnce && !sessions.isEmpty {
            print("📦 相册缓存命中，跳过重新加载")
            return
        }
        
        // 设置加载状态
        isLoading = true
        
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
                
                // ✅ 优化：预加载 photoAnalyses 关系，避免延迟加载（N+1 查询问题）
                request.relationshipKeyPathsForPrefetching = ["photoAnalyses"]
                
                // ✅ 优化：设置批量大小，减少内存占用
                request.fetchBatchSize = 20
        
        do {
            let entities = try context.fetch(request)
            print("📊 查询到 \(entities.count) 个分析会话")
            
                    // ✅ 优化：预分配数组容量
                    sessionInfos.reserveCapacity(entities.count)
                    
                    for entity in entities {
                        guard let id = entity.id else { continue }
                
                let name = entity.customName ?? "未命名"
                let date = entity.customDate ?? entity.timestamp ?? Date()
                let photoCount = Int(entity.totalPhotoCount)
                let isFavorite = entity.isFavorite
                
                        // 使用保存的封面照片 ID（第一张照片）
                        let coverAssetId = entity.coverAssetIdentifier
                
                        sessionInfos.append(AnalysisSessionInfo(
                    id: id,
                    name: name,
                    date: date,
                    photoCount: photoCount,
                    isFavorite: isFavorite,
                    coverAssetIdentifier: coverAssetId
                        ))
            }
                } catch {
                    print("❌ 加载分析会话失败: \(error.localizedDescription)")
                }
            }
            
            // 更新 UI（在主线程）
            await MainActor.run {
                self.sessions = sessionInfos
                self.isLoading = false
                self.hasLoadedOnce = true  // ✅ 标记已加载
                print("✅ 加载了 \(sessionInfos.count) 个分析会话")
            }
        }
    }
    
    /// 强制刷新会话列表（用于新增/删除后）
    func forceRefresh() {
        hasLoadedOnce = false
        loadSessions()
    }
    
    /// 预加载最近的分析结果（后台执行，不阻塞 UI）
    func preloadRecentResults() {
        // 如果会话列表还没加载，跳过（不要递归）
        guard !sessions.isEmpty else { return }
        
        // 只预加载前 3 个分析结果（最常用的）
        let recentSessionIds = sessions.prefix(3).map { $0.id }
        guard !recentSessionIds.isEmpty else { return }
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            print("🔥 预加载最近 \(recentSessionIds.count) 个分析结果...")
            
            for sessionId in recentSessionIds {
                // 如果缓存中已有，跳过
                if AnalysisResultCache.shared.result(for: sessionId) != nil {
                    continue
                }
                
                // 后台加载并缓存
                let result = await self.loadAnalysisResultAsync(for: sessionId)
                if result != nil {
                    print("✅ 预加载完成: \(sessionId)")
                }
            }
            
            print("✅ 预加载完成")
        }
    }
    
    /// 从 Core Data 加载完整的分析结果（异步版本，在后台线程执行）
    func loadAnalysisResultAsync(for sessionId: UUID) async -> AnalysisResult? {
        // ✅ 优化：先检查缓存
        if let cachedResult = AnalysisResultCache.shared.result(for: sessionId) {
            print("📦 分析结果缓存命中: \(sessionId)")
            return cachedResult
        }
        
        // 缓存未命中，从 Core Data 加载
        let result = await Task.detached(priority: .userInitiated) { [coreDataManager] in
            return AnalysisLibraryViewModel.loadAnalysisResultBackground(
                sessionId: sessionId,
                coreDataManager: coreDataManager
            )
        }.value
        
        // 存入缓存
        if let result = result {
            AnalysisResultCache.shared.setResult(result, for: sessionId)
            print("📦 分析结果已缓存: \(sessionId)")
        }
        
        return result
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
            
            // 加载照片信息（按 sortOrder 排序，保持用户选择时的顺序）
            if let photoEntities = entity.photoAnalyses?.allObjects as? [PhotoAnalysisEntity] {
                    analysisResult.photoInfos = photoEntities.sorted { $0.sortOrder < $1.sortOrder }.map { photoEntity in
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
                    
                    // 加载明度中位数和对比度
                    let median = photoEntity.brightnessMedian
                    let contrast = photoEntity.brightnessContrast
                    if median != 0 || contrast != 0 {
                        photoInfo.brightnessMedian = median
                        photoInfo.brightnessContrast = contrast
                    } else if photoInfo.brightnessCDF != nil {
                        // 如果有 CDF 但没有统计值，重新计算
                        photoInfo.computeBrightnessStatistics()
                    }
                    
                    // 加载高级色彩分析
                    if let advancedData = photoEntity.advancedColorAnalysisData,
                       let advancedAnalysis = try? JSONDecoder().decode(AdvancedColorAnalysis.self, from: advancedData) {
                        photoInfo.advancedColorAnalysis = advancedAnalysis
                    }
                    
                    // 加载照片元数据（用于收藏时获取照片时间和相机镜头信息）
                    // 处理 metadata 可能是 to-many 关系的情况
                    let metadataRelation = photoEntity.value(forKey: "metadata")
                    var metadataEntity: PhotoMetadataEntity?
                    
                    if let set = metadataRelation as? NSSet {
                        if let first = set.allObjects.first as? PhotoMetadataEntity {
                            metadataEntity = first
                        }
                    } else if let single = metadataRelation as? PhotoMetadataEntity {
                        metadataEntity = single
                    }
                    
                    if let entity = metadataEntity {
                        var metadata = PhotoMetadata()
                        metadata.captureDate = entity.captureDate
                        metadata.aperture = entity.aperture != 0 ? entity.aperture : nil
                        metadata.shutterSpeed = entity.shutterSpeed
                        metadata.iso = entity.iso != 0 ? Int(entity.iso) : nil
                        metadata.focalLength = entity.focalLength != 0 ? entity.focalLength : nil
                        metadata.cameraMake = entity.cameraMake
                        metadata.cameraModel = entity.cameraModel
                        metadata.lensModel = entity.lensModel
                        photoInfo.metadata = metadata
                        print("📷 加载 metadata: camera=\(entity.cameraMake ?? "nil")/\(entity.cameraModel ?? "nil"), lens=\(entity.lensModel ?? "nil"), date=\(entity.captureDate?.description ?? "nil")")
                    } else {
                        print("⚠️ 照片 \(photoEntity.assetLocalIdentifier ?? "unknown") 没有 metadata")
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

// MARK: - 编辑照片集信息弹窗（与收藏弹窗一致）
struct SessionEditAlertView: View {
    let session: AnalysisSessionInfo
    let onConfirm: (String, Date) -> Void
    let onCancel: () -> Void
    
    @State private var sessionName: String
    @State private var sessionDate: Date
    
    init(session: AnalysisSessionInfo, onConfirm: @escaping (String, Date) -> Void, onCancel: @escaping () -> Void) {
        self.session = session
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _sessionName = State(initialValue: session.name)
        _sessionDate = State(initialValue: session.date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("编辑信息")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("名称")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("请输入名称", text: $sessionName)
                        .textFieldStyle(.roundedBorder)
                }
                
                        DatePicker("", selection: $sessionDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            Divider()
            
            HStack(spacing: 0) {
                Button("取消") {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.primary)
                
                Divider()
                    .frame(height: 44)
                
                Button("确认") {
                    onConfirm(sessionName.trimmingCharacters(in: .whitespacesAndNewlines), sessionDate)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.blue)
                .fontWeight(.semibold)
                .disabled(sessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

#Preview {
    AnalysisLibraryView()
}
