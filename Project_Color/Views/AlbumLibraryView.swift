//
//  AlbumLibraryView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/19.
//  相册库：显示所有已分析照片的相册
//

import SwiftUI
import Photos
import CoreData
import Combine

/// 相册信息
struct AlbumInfo: Identifiable {
    let id: String  // albumIdentifier
    let name: String
    let photoCount: Int
    var coverAssetIdentifier: String?  // 最新照片的 assetLocalIdentifier
    var date: Date?  // 相册日期（从 session 获取）
    var isFavorite: Bool = false
}

struct AlbumLibraryView: View {
    @StateObject private var viewModel = AlbumLibraryViewModel()
    @State private var selectedAlbum: AlbumInfo?
    @State private var albumToEdit: AlbumInfo?
    @State private var albumToDelete: AlbumInfo?
    @State private var showDeleteAlert = false
    @State private var showEditOverlay = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.albums.isEmpty {
                    emptyStateView
                } else {
                    albumGridView
                }
            }
            .navigationTitle("相册")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            viewModel.loadAlbums()
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumPhotosView(album: album)
        }
        .confirmationDialog("确认删除", isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let album = albumToDelete {
                    viewModel.deleteAlbum(albumId: album.id)
                    albumToDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                albumToDelete = nil
            }
        } message: {
            if let album = albumToDelete {
                Text("确定要删除相册「\(album.name)」吗？此操作将删除该相册的所有照片分析记录，且无法撤销。")
            }
        }
        .overlay(alignment: .center) {
            if showEditOverlay, let album = albumToEdit {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showEditOverlay = false
                            albumToEdit = nil
                        }
                    
                    AlbumEditAlertView(
                        album: album,
                        onConfirm: { name, date in
                            viewModel.updateAlbumInfo(albumId: album.id, name: name, date: date)
                            albumToEdit = nil
                            showEditOverlay = false
                            viewModel.loadAlbums()
                        },
                        onCancel: {
                            albumToEdit = nil
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
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text("暂无相册")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("分析照片后\n相册会显示在这里")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - 相册网格（正方形圆角矩形）
    private var albumGridView: some View {
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
                    ForEach(viewModel.albums) { album in
                        AlbumCard(
                            album: album,
                            cardSize: cardSize,
                            onEdit: {
                                DispatchQueue.main.async {
                                    albumToEdit = album
                                    showEditOverlay = true
                                }
                            },
                            onFavorite: {
                                print("📌 onFavorite 闭包被调用: \(album.id)")
                                viewModel.toggleFavorite(albumId: album.id)
                            },
                            onDelete: {
                                DispatchQueue.main.async {
                                    albumToDelete = album
                                    showDeleteAlert = true
                                }
                            }
                        )
                            .onTapGesture {
                                selectedAlbum = album
                            }
                    }
                }
                .padding(padding)
            }
        }
    }
}

// MARK: - 相册卡片（正方形）
struct AlbumCard: View {
    let album: AlbumInfo
    let cardSize: CGFloat
    let onEdit: () -> Void
    let onFavorite: () -> Void
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
                            ProgressView()
                        )
                }
            }
            .frame(width: cardSize, height: cardSize)
            .clipped()
            .cornerRadius(12)
            .contextMenu {
                Button {
                    print("📌 contextMenu 收藏按钮被点击")
                    onFavorite()
                } label: {
                    Label(album.isFavorite ? "移除收藏" : "收藏", systemImage: album.isFavorite ? "heart.slash" : "heart")
                }
                
                Button(action: onEdit) {
                    Label("编辑信息", systemImage: "square.and.pencil")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            }
            
            // 相册名称
            Text(album.name)
                .font(.headline)
                .lineLimit(1)
                .frame(width: cardSize, alignment: .leading)
            
            // 照片数量
            Text("\(album.photoCount) 张照片")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: cardSize, alignment: .leading)
        }
        .onAppear {
            loadCoverImage()
        }
    }
    
    private func loadCoverImage() {
        guard let assetId = album.coverAssetIdentifier else { return }
        
        // ✅ 优化：在后台线程加载封面图片
        Task.detached(priority: .userInitiated) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            options.isSynchronous = true  // 在后台线程同步加载更高效
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                    Task { @MainActor in
                    self.coverImage = image
                    }
                }
            }
        }
    }
}

// MARK: - ViewModel
class AlbumLibraryViewModel: ObservableObject {
    @Published var albums: [AlbumInfo] = []
    @Published var isLoading = false
    @Published private(set) var favoriteAlbumIds: Set<String> = AlbumFavoritesStore.shared.load()
    
    private let coreDataManager = CoreDataManager.shared
    
    func loadAlbums() {
        isLoading = true
        
        // ✅ 优化：在后台线程执行 Core Data 查询
        Task.detached(priority: .userInitiated) { [coreDataManager, weak self] in
            guard let self = self else { return }
            let context = coreDataManager.newBackgroundContext()
            var albumInfos: [AlbumInfo] = []
            
            context.performAndWait {
        let request = PhotoAnalysisEntity.fetchRequest()
        request.predicate = NSPredicate(format: "albumIdentifier != nil")
                
                // ✅ 优化：预加载 session 关系
                request.relationshipKeyPathsForPrefetching = ["session"]
        
        do {
            let entities = try context.fetch(request)
            print("📊 查询到 \(entities.count) 个包含相册信息的 PhotoAnalysisEntity")
            
            // 按 albumIdentifier 分组
            var albumDict: [String: (name: String, photos: [PhotoAnalysisEntity])] = [:]
            var skippedCount = 0
            var reasons: [String: Int] = [:]
            
            for entity in entities {
                // 调试：检查每个实体
                let hasAlbumId = entity.albumIdentifier != nil
                let hasAlbumName = entity.albumName != nil
                let session = self.primarySession(for: entity)
                let hasSession = session != nil
                
                if !hasAlbumId {
                    reasons["无 albumIdentifier", default: 0] += 1
                    skippedCount += 1
                    continue
                }
                if !hasAlbumName {
                    reasons["无 albumName", default: 0] += 1
                    skippedCount += 1
                    continue
                }
                if !hasSession {
                    reasons["无 session", default: 0] += 1
                    skippedCount += 1
                    continue
                }
                
                guard let albumId = entity.albumIdentifier,
                      let albumName = entity.albumName else {
                    continue
                }
                
                if albumDict[albumId] == nil {
                    albumDict[albumId] = (albumName, [])
                    print("   ➕ 新相册: \(albumName) (ID: \(albumId.prefix(8))...)")
                }
                albumDict[albumId]?.photos.append(entity)
            }
            
            print("   ⏭️ 跳过 \(skippedCount) 个实体:")
            for (reason, count) in reasons {
                print("      - \(reason): \(count)")
            }
            
            // 转换为 AlbumInfo 数组
                albumInfos = albumDict.map { (id, value) -> AlbumInfo in
                // 获取最新照片作为封面
                let sortedPhotos = value.photos.sorted {
                        (self.primarySession(for: $0)?.timestamp ?? Date.distantPast) >
                        (self.primarySession(for: $1)?.timestamp ?? Date.distantPast)
                }
                let coverAssetId = sortedPhotos.first?.assetLocalIdentifier
                    
                    // 获取相册日期（从最新的 session 获取）
                    let latestSession = sortedPhotos.first.flatMap { self.primarySession(for: $0) }
                    let albumDate = latestSession?.customDate ?? latestSession?.timestamp
                
                return AlbumInfo(
                    id: id,
                    name: value.name,
                    photoCount: value.photos.count,
                        coverAssetIdentifier: coverAssetId,
                        date: albumDate,
                        isFavorite: self.favoriteAlbumIds.contains(id)
                )
            }
            
            // 按相册名称排序
                albumInfos.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
                print("✅ 加载了 \(albumInfos.count) 个相册")
        } catch {
            print("❌ 加载相册失败: \(error.localizedDescription)")
            }
            }
            
            // 更新 UI（在主线程）
            await MainActor.run {
                self.albums = albumInfos
                self.isLoading = false
            }
        }
    }
    
    /// 兼容旧版本数据模型（session 可能为 to-one 或 to-many）
    private func primarySession(for photo: PhotoAnalysisEntity) -> AnalysisSessionEntity? {
        let rawValue = photo.value(forKey: "session")
        if let session = rawValue as? AnalysisSessionEntity {
            return session
        }
        if let rawSet = rawValue as? NSSet,
           let session = rawSet.anyObject() as? AnalysisSessionEntity {
            return session
        }
        if let sessions = rawValue as? Set<AnalysisSessionEntity> {
            return sessions.first
        }
        return nil
    }
    
    // MARK: - 相册操作
    
    /// 更新相册信息（名称和日期）
    func updateAlbumInfo(albumId: String, name: String, date: Date) {
        let context = coreDataManager.viewContext
        let request = PhotoAnalysisEntity.fetchRequest()
        request.predicate = NSPredicate(format: "albumIdentifier == %@", albumId)
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                entity.albumName = name
                // 如果有 session，也更新 session 的日期
                if let session = primarySession(for: entity) {
                    session.customDate = date
                }
            }
            try context.save()
            print("✅ 更新相册信息成功: \(name)")
        } catch {
            print("❌ 更新相册信息失败: \(error.localizedDescription)")
        }
    }
    
    /// 切换收藏状态
    func toggleFavorite(albumId: String) {
        print("📌 toggleFavorite 被调用: albumId=\(albumId)")
        print("📌 当前 favoriteAlbumIds: \(favoriteAlbumIds)")
        
        let willFavorite = !favoriteAlbumIds.contains(albumId)
        if willFavorite {
            favoriteAlbumIds.insert(albumId)
        } else {
            favoriteAlbumIds.remove(albumId)
        }
        
        print("📌 更新后 favoriteAlbumIds: \(favoriteAlbumIds)")
        AlbumFavoritesStore.shared.save(favoriteAlbumIds)
        
        // 更新 UI：直接修改对应元素，避免重新创建整个数组
        if let index = albums.firstIndex(where: { $0.id == albumId }) {
            albums[index].isFavorite = willFavorite
        }
        print("📌 相册\(willFavorite ? "加入" : "移除")收藏: \(albumId)")
    }
    
    /// 删除相册（删除该相册的所有照片分析记录）
    func deleteAlbum(albumId: String) {
        let context = coreDataManager.viewContext
        let request = PhotoAnalysisEntity.fetchRequest()
        request.predicate = NSPredicate(format: "albumIdentifier == %@", albumId)
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
            print("✅ 删除相册成功: \(albumId)")
            favoriteAlbumIds.remove(albumId)
            AlbumFavoritesStore.shared.save(favoriteAlbumIds)
            // 重新加载相册列表
            loadAlbums()
        } catch {
            print("❌ 删除相册失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 编辑相册信息弹窗（与收藏弹窗样式一致）
struct AlbumEditAlertView: View {
    let album: AlbumInfo
    let onConfirm: (String, Date) -> Void
    let onCancel: () -> Void
    
    @State private var albumName: String
    @State private var albumDate: Date
    
    init(album: AlbumInfo, onConfirm: @escaping (String, Date) -> Void, onCancel: @escaping () -> Void) {
        self.album = album
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _albumName = State(initialValue: album.name)
        _albumDate = State(initialValue: album.date ?? Date())
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
                    TextField("请输入名称", text: $albumName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("日期")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $albumDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
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
                    onConfirm(albumName.trimmingCharacters(in: .whitespacesAndNewlines), albumDate)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.blue)
                .fontWeight(.semibold)
                .disabled(albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AlbumLibraryView()
}
