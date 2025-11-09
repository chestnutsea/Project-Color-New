//
//  AlbumViewModel.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//

import SwiftUI
import Photos
import Combine

// MARK: - 相册模型
struct Album: Identifiable, Equatable {
    let id: String
    let title: String
    let assetCollection: PHAssetCollection?
    let coverImage: UIImage?
    let photosCount: Int
    
    init(id: String, title: String, assetCollection: PHAssetCollection?, coverImage: UIImage?, photosCount: Int) {
        self.id = id
        self.title = title
        self.assetCollection = assetCollection
        self.coverImage = coverImage
        self.photosCount = photosCount
    }
    
    // 实现 Equatable，只比较 id
    static func == (lhs: Album, rhs: Album) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 相册 ViewModel
@MainActor
class AlbumViewModel: ObservableObject {
    @Published var albums: [Album] = []
    @Published var isLoading = false
    
    // MARK: - 布局常量
    let cardCornerRadius: CGFloat = 20
    
    /// 计算相册卡片边长：(屏幕宽度 - 50) / 2
    func calculateCardSize(screenWidth: CGFloat) -> CGFloat {
        return (screenWidth - 50) / 2
    }
    
    // MARK: - 加载相册
    func loadAlbums() {
        isLoading = true
        
        Task {
            var loadedAlbums: [Album] = []
            
            // 1. 添加"全部"相册
            let allPhotosAlbum = await createAllPhotosAlbum()
            loadedAlbums.append(allPhotosAlbum)
            
            // 2. 获取用户相册
            let userAlbums = await fetchUserAlbums()
            loadedAlbums.append(contentsOf: userAlbums)
            
            self.albums = loadedAlbums
            self.isLoading = false
        }
    }
    
    // MARK: - 创建"全部"相册
    private func createAllPhotosAlbum() async -> Album {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let count = allPhotos.count
        
        // 获取最后一张照片作为封面
        var coverImage: UIImage?
        if count > 0, let lastAsset = allPhotos.firstObject {
            coverImage = await fetchThumbnail(for: lastAsset)
        }
        
        return Album(
            id: "all_photos",
            title: "全部",
            assetCollection: nil,
            coverImage: coverImage,
            photosCount: count
        )
    }
    
    // MARK: - 获取用户相册
    private func fetchUserAlbums() async -> [Album] {
        var albums: [Album] = []
        
        // 获取用户创建的相册
        let userCollections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: nil
        )
        
        // 获取智能相册（如最近项目、个人收藏等）
        let smartCollections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .albumRegular,
            options: nil
        )
        
        // 处理用户相册
        albums.append(contentsOf: await processCollections(userCollections))
        
        // 处理智能相册
        albums.append(contentsOf: await processCollections(smartCollections))
        
        return albums
    }
    
    // MARK: - 处理相册集合
    private func processCollections(_ collections: PHFetchResult<PHAssetCollection>) async -> [Album] {
        var albums: [Album] = []
        
        collections.enumerateObjects { collection, _, _ in
            // 不排序，使用相册原始顺序，第一张就是系统显示的封面
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            let count = assets.count
            
            // 只显示有照片的相册
            guard count > 0 else { return }
            
            // 创建 Task 来获取封面
            Task {
                var coverImage: UIImage?
                // 使用第一张照片作为封面（相册的原始封面）
                if let firstAsset = assets.firstObject {
                    coverImage = await self.fetchThumbnail(for: firstAsset)
                }
                
                let album = Album(
                    id: collection.localIdentifier,
                    title: collection.localizedTitle ?? "未命名相册",
                    assetCollection: collection,
                    coverImage: coverImage,
                    photosCount: count
                )
                
                await MainActor.run {
                    albums.append(album)
                }
            }
        }
        
        // 等待一小段时间让所有 Task 完成
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        return albums
    }
    
    // MARK: - 获取缩略图
    private func fetchThumbnail(for asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            // 请求合适大小的缩略图
            let targetSize = CGSize(width: 500, height: 500)
            
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

