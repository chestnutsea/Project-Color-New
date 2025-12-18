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
#if canImport(UIKit)
import UIKit
#endif

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
        // iOS 16+ 兼容：使用条件编译选择最佳导航方案
        Group {
            if #available(iOS 16.0, *) {
        NavigationStack {
                    contentView
                }
            } else {
                NavigationView {
                    contentView
                }
                .navigationViewStyle(.stack)
            }
        }
        .onAppear {
            viewModel.loadAlbums()
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumPhotosView(album: album)
        }
        .confirmationDialog(L10n.Album.deleteConfirmTitle.localized, isPresented: $showDeleteAlert, titleVisibility: .visible) {
            deleteAlertButtons
        } message: {
            deleteAlertMessage
        }
        .overlay(alignment: .center) {
            editOverlayView
        }
    }
    
    // MARK: - 主内容视图
    private var contentView: some View {
            ScrollView {
                VStack(spacing: 0) {
                    // 自定义标题
                    Text(L10n.Album.title.localized)
                        .font(.system(size: AppStyle.tabTitleFontSize, weight: AppStyle.tabTitleFontWeight))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, AppStyle.tabTitleTopPadding)
                        .padding(.bottom, 8)
                    
                    // 内容区域
                    Group {
                        if viewModel.albums.isEmpty {
                            emptyStateView
                        } else {
                            albumGridView
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    
    // MARK: - 辅助视图
    @ViewBuilder
    private var deleteAlertButtons: some View {
            Button(L10n.Album.delete.localized, role: .destructive) {
                if let album = albumToDelete {
                    viewModel.deleteAlbum(albumId: album.id)
                    albumToDelete = nil
                }
            }
            Button(L10n.Common.cancel.localized, role: .cancel) {
                albumToDelete = nil
            }
    }
    
    @ViewBuilder
    private var deleteAlertMessage: some View {
            if let album = albumToDelete {
                Text(L10n.Album.deleteConfirmMessage.localized.replacingOccurrences(of: "%@", with: album.name))
            }
        }
    
    @ViewBuilder
    private var editOverlayView: some View {
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
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text(L10n.Album.emptyTitle.localized)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(L10n.Album.emptyMessage.localized)
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - 相册网格（正方形圆角矩形）
    private var albumGridView: some View {
        let spacing: CGFloat = 16
        let gridPadding: CGFloat = 16  // 网格内部的 padding
        let outerPadding: CGFloat = 16  // VStack 外层的 padding
        #if canImport(UIKit)
        let screenWidth = UIScreen.main.bounds.width
        #else
        let screenWidth: CGFloat = 375 // macOS 默认宽度
        #endif
        // 计算可用宽度：屏幕宽度 - 外层 padding * 2 - 网格 padding * 2 - 卡片间距
        let availableWidth = screenWidth - (outerPadding * 2) - (gridPadding * 2) - spacing
        let cardSize = availableWidth / 2
        
        return LazyVGrid(
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
        .padding(gridPadding)
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
                    HStack {
                        Image(systemName: album.isFavorite ? "heart.slash" : "heart")
                            .foregroundColor(.primary)
                        Text(album.isFavorite ? L10n.Favorite.remove.localized : L10n.Favorite.add.localized)
                    }
                }
                
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.primary)
                        Text(L10n.Album.editInfo.localized)
                    }
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text(L10n.Album.delete.localized)
                    }
                }
            }
            
            // 相册名称
            Text(album.name)
                .font(.headline)
                .lineLimit(1)
                .frame(width: cardSize, alignment: .leading)
            
            // 照片数量
            Text(L10n.Album.photosCountText(count: album.photoCount))
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
                
                // 获取收藏状态（从 session.isFavorite）
                let isFavorite = latestSession?.isFavorite ?? false
                
                return AlbumInfo(
                    id: id,
                    name: value.name,
                    photoCount: value.photos.count,
                        coverAssetIdentifier: coverAssetId,
                        date: albumDate,
                        isFavorite: isFavorite
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
        // Safely access the session using KVC
        guard let rawValue = photo.value(forKey: "session") else {
            return nil
        }
        
        // Handle direct AnalysisSessionEntity (expected case)
        if let session = rawValue as? AnalysisSessionEntity {
            return session
        }
        
        // Handle NSSet (legacy data model)
        if let rawSet = rawValue as? NSSet {
            return rawSet.anyObject() as? AnalysisSessionEntity
        }
        
        // Handle Swift Set (legacy data model)
        if let sessions = rawValue as? Set<AnalysisSessionEntity> {
            return sessions.first
        }
        
        // Log unexpected types
        print("⚠️  Unexpected session type: \(type(of: rawValue))")
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
    
    /// 切换收藏状态（更新相册对应的所有 session 的 isFavorite）
    func toggleFavorite(albumId: String) {
        guard let index = albums.firstIndex(where: { $0.id == albumId }) else { return }
        
        let willFavorite = !albums[index].isFavorite
        print("📌 toggleFavorite: albumId=\(albumId), willFavorite=\(willFavorite)")
        
        // 更新 Core Data 中所有属于该相册的 session 的 isFavorite
        let context = coreDataManager.viewContext
        let request = PhotoAnalysisEntity.fetchRequest()
        request.predicate = NSPredicate(format: "albumIdentifier == %@", albumId)
        request.relationshipKeyPathsForPrefetching = ["session"]
        
        do {
            let entities = try context.fetch(request)
            var updatedSessions: Set<NSManagedObjectID> = []
            
            for entity in entities {
                if let session = primarySession(for: entity),
                   !updatedSessions.contains(session.objectID) {
                    session.isFavorite = willFavorite
                    updatedSessions.insert(session.objectID)
                }
            }
            
            try context.save()
            print("✅ 更新 \(updatedSessions.count) 个 session 的收藏状态为 \(willFavorite)")
            
            // 更新 UI
            albums[index].isFavorite = willFavorite
        } catch {
            print("❌ 更新收藏状态失败: \(error)")
        }
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
            Text(L10n.Album.editTitle.localized)
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Album.name.localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField(L10n.Album.namePlaceholder.localized, text: $albumName)
                        .textFieldStyle(.roundedBorder)
                }
                
                DatePicker("", selection: $albumDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            Divider()
            
            HStack(spacing: 0) {
                Button(L10n.Common.cancel.localized) {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.primary)
                
                Divider()
                    .frame(height: 44)
                
                Button(L10n.Common.confirm.localized) {
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
