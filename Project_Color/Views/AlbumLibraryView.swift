//
//  AlbumLibraryView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/19.
//  相册库：显示所有"我的作品"的相册
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
}

struct AlbumLibraryView: View {
    @StateObject private var viewModel = AlbumLibraryViewModel()
    @State private var selectedAlbum: AlbumInfo?
    
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
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无相册")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("分析照片并标记为\"我的作品\"后\n相册会显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                        AlbumCard(album: album, cardSize: cardSize)
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
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false  // 只加载本地缓存
        
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
class AlbumLibraryViewModel: ObservableObject {
    @Published var albums: [AlbumInfo] = []
    
    private let coreDataManager = CoreDataManager.shared
    
    func loadAlbums() {
        let context = coreDataManager.viewContext
        let request = PhotoAnalysisEntity.fetchRequest()
        request.predicate = NSPredicate(format: "albumIdentifier != nil")
        
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
                let session = primarySession(for: entity)
                let hasSession = session != nil
                let isPersonal = session?.isPersonalWork ?? false
                
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
                if !isPersonal {
                    reasons["非我的作品", default: 0] += 1
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
            let albumInfos = albumDict.map { (id, value) -> AlbumInfo in
                // 获取最新照片作为封面
                let sortedPhotos = value.photos.sorted {
                    (primarySession(for: $0)?.timestamp ?? Date.distantPast) >
                    (primarySession(for: $1)?.timestamp ?? Date.distantPast)
                }
                let coverAssetId = sortedPhotos.first?.assetLocalIdentifier
                
                return AlbumInfo(
                    id: id,
                    name: value.name,
                    photoCount: value.photos.count,
                    coverAssetIdentifier: coverAssetId
                )
            }
            
            // 按相册名称排序
            let sorted = albumInfos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.albums = sorted
            }
            
            print("✅ 加载了 \(sorted.count) 个相册")
        } catch {
            print("❌ 加载相册失败: \(error.localizedDescription)")
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
}

// MARK: - Preview
#Preview {
    AlbumLibraryView()
}
