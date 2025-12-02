//
//  CacheManager.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/30.
//  缓存管理：封面图缓存 + 分析结果缓存
//

import UIKit
import Photos
import CoreData

// MARK: - 封面图缓存

/// 封面图缓存管理器（使用 NSCache 自动管理内存）
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let targetSize = CGSize(width: 300, height: 300)
    
    private init() {
        // 设置缓存限制（可选）
        cache.countLimit = 100  // 最多缓存 100 张封面图
    }
    
    // MARK: - 公开接口
    
    /// 获取缓存的封面图
    func image(for assetId: String) -> UIImage? {
        return cache.object(forKey: assetId as NSString)
    }
    
    /// 缓存封面图
    func setImage(_ image: UIImage, for assetId: String) {
        cache.setObject(image, forKey: assetId as NSString)
    }
    
    /// 预加载封面图（后台执行）
    func preloadCovers(assetIds: [String]) async {
        let idsToLoad = assetIds.filter { cache.object(forKey: $0 as NSString) == nil }
        
        guard !idsToLoad.isEmpty else {
            print("📦 封面图缓存：全部已缓存，无需加载")
            return
        }
        
        print("📦 封面图缓存：开始预加载 \(idsToLoad.count) 张封面图...")
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: idsToLoad, options: nil)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = true
        
        fetchResult.enumerateObjects { asset, _, _ in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: self.targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    self.cache.setObject(image, forKey: asset.localIdentifier as NSString)
                }
            }
        }
        
        print("✅ 封面图缓存：预加载完成")
    }
    
    /// 清空缓存
    func clearCache() {
        cache.removeAllObjects()
        print("🗑️ 封面图缓存已清空")
    }
}

// MARK: - 分析结果缓存

/// 分析结果缓存管理器
final class AnalysisResultCache {
    static let shared = AnalysisResultCache()
    
    // 使用 NSCache 包装器来存储 AnalysisResult
    private let cache = NSCache<NSString, AnalysisResultWrapper>()
    
    private init() {
        // 设置缓存限制
        cache.countLimit = 20  // 最多缓存 20 个分析结果
    }
    
    // MARK: - 公开接口
    
    /// 获取缓存的分析结果
    func result(for sessionId: UUID) -> AnalysisResult? {
        return cache.object(forKey: sessionId.uuidString as NSString)?.result
    }
    
    /// 缓存分析结果
    func setResult(_ result: AnalysisResult, for sessionId: UUID) {
        let wrapper = AnalysisResultWrapper(result: result)
        cache.setObject(wrapper, forKey: sessionId.uuidString as NSString)
    }
    
    /// 移除指定的缓存
    func removeResult(for sessionId: UUID) {
        cache.removeObject(forKey: sessionId.uuidString as NSString)
    }
    
    /// 清空缓存
    func clearCache() {
        cache.removeAllObjects()
        print("🗑️ 分析结果缓存已清空")
    }
}

// NSCache 需要存储 class 类型，所以用 wrapper 包装 struct
private class AnalysisResultWrapper {
    let result: AnalysisResult
    
    init(result: AnalysisResult) {
        self.result = result
    }
}

// MARK: - 预热管理器

/// 缓存预热管理器（App 启动时后台预加载）
final class CachePreloader {
    static let shared = CachePreloader()
    
    private var hasPreloaded = false
    
    private init() {}
    
    /// 启动预热（在后台线程执行，不阻塞主线程）
    func startPreloading() {
        guard !hasPreloaded else { return }
        hasPreloaded = true
        
        // ✅ 使用低优先级后台任务，不阻塞 App 启动
        Task.detached(priority: .background) {
            // 延迟 1 秒再开始预热，确保 App 已完全启动
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            print("🔥 缓存预热：开始...")
            let startTime = Date()
            
            // 只预热封面图（轻量操作）
            let coverAssetIds = await self.fetchCoverAssetIds()
            if !coverAssetIds.isEmpty {
                await ThumbnailCache.shared.preloadCovers(assetIds: coverAssetIds)
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ 缓存预热：完成，耗时 \(String(format: "%.2f", elapsed)) 秒")
        }
    }
    
    /// 从 Core Data 获取所有封面图的 asset ID
    private func fetchCoverAssetIds() async -> [String] {
        let context = CoreDataManager.shared.newBackgroundContext()
        var assetIds: [String] = []
        
        context.performAndWait {
            let request: NSFetchRequest<AnalysisSessionEntity> = AnalysisSessionEntity.fetchRequest()
            request.relationshipKeyPathsForPrefetching = ["photoAnalyses"]
            
            do {
                let sessions = try context.fetch(request)
                for session in sessions {
                    if let photoAnalyses = session.photoAnalyses as? Set<PhotoAnalysisEntity>,
                       let firstPhoto = photoAnalyses.first,
                       let assetId = firstPhoto.assetLocalIdentifier {
                        assetIds.append(assetId)
                    }
                }
            } catch {
                print("❌ 获取封面图 ID 失败: \(error.localizedDescription)")
            }
        }
        
        return assetIds
    }
}

// MARK: - 相册预热管理器

/// 相册预热管理器：预热相册列表和默认相册的缩略图
final class AlbumPreheater {
    static let shared = AlbumPreheater()
    
    private let cachingManager = PHCachingImageManager()
    private let thumbnailSize = CGSize(width: 200, height: 200)
    private let preheatBatchSize = 50
    
    /// 预热后的相册列表（供 CustomPhotoPickerView 直接使用）
    private(set) var preheatedAlbums: [PreheatedAlbumInfo] = []
    
    /// 预热后的默认相册照片（前 100 张）
    private(set) var preheatedPhotos: [PHAsset] = []
    
    /// 是否已完成预热
    private(set) var isPreheated = false
    
    private init() {}
    
    /// 预热默认相册（在后台执行）- 简化版，只预热最基本的数据
    func preheatDefaultAlbum() async {
        guard !isPreheated else {
            print("📦 相册预热：已完成，跳过")
            return
        }
        
        // 检查相册权限
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            print("⚠️ 相册预热：无权限，跳过")
            return
        }
        
        print("🔥 相册预热：开始...")
        let startTime = Date()
        
        // ✅ 简化：只预热默认相册的前 50 张照片的缩略图
        let defaultCollection = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumUserLibrary,
            options: nil
        ).firstObject
        
        if let collection = defaultCollection {
            let photos = await fetchPhotos(from: collection, limit: 50)
            
            await MainActor.run {
                self.preheatedPhotos = photos
            }
            
            // 预热缩略图
            if !photos.isEmpty {
                preheatThumbnailsSync(for: photos)
            }
        }
        
        await MainActor.run {
            self.isPreheated = true
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("✅ 相册预热：完成，\(preheatedPhotos.count) 张照片，耗时 \(String(format: "%.2f", elapsed)) 秒")
    }
    
    /// 重置预热状态（用于权限变更后或照片库变化后）
    func reset() {
        isPreheated = false
        preheatedAlbums = []
        preheatedPhotos = []
        cachingManager.stopCachingImagesForAllAssets()
        print("🔄 相册预热：已重置")
    }
    
    /// 标记需要刷新（下次进入扫描页时重新预热）
    func markNeedsRefresh() {
        isPreheated = false
        print("🔄 相册预热：标记需要刷新")
    }
    
    // MARK: - Private
    
    private func fetchAlbumList() async -> [PreheatedAlbumInfo] {
        var albums: [PreheatedAlbumInfo] = []
        var addedIds = Set<String>()
        
        let countOptions = PHFetchOptions()
        countOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        countOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        
        // 1. 所有照片
        let recentAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumUserLibrary,
            options: nil
        )
        
        recentAlbums.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: countOptions)
            if assets.count > 0 && !addedIds.contains(collection.localIdentifier) {
                addedIds.insert(collection.localIdentifier)
                albums.append(PreheatedAlbumInfo(
                    id: collection.localIdentifier,
                    collection: collection,
                    title: self.localizedAlbumTitle(collection),
                    count: assets.count
                ))
            }
        }
        
        // 2. 用户相册
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: nil
        )
        
        userAlbums.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: countOptions)
            if assets.count > 0 && !addedIds.contains(collection.localIdentifier) {
                addedIds.insert(collection.localIdentifier)
                albums.append(PreheatedAlbumInfo(
                    id: collection.localIdentifier,
                    collection: collection,
                    title: collection.localizedTitle ?? "未命名相册",
                    count: assets.count
                ))
            }
        }
        
        // 3. 其他智能相册
        let otherSmartTypes: [PHAssetCollectionSubtype] = [
            .smartAlbumFavorites,
            .smartAlbumScreenshots,
            .smartAlbumSelfPortraits,
            .smartAlbumPanoramas
        ]
        
        for subtype in otherSmartTypes {
            let collections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: subtype,
                options: nil
            )
            
            collections.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: countOptions)
                if assets.count > 0 && !addedIds.contains(collection.localIdentifier) {
                    addedIds.insert(collection.localIdentifier)
                    albums.append(PreheatedAlbumInfo(
                        id: collection.localIdentifier,
                        collection: collection,
                        title: self.localizedAlbumTitle(collection),
                        count: assets.count
                    ))
                }
            }
        }
        
        return albums
    }
    
    private func fetchPhotos(from collection: PHAssetCollection, limit: Int) async -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        
        let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
        var photos: [PHAsset] = []
        photos.reserveCapacity(min(limit, fetchResult.count))
        
        fetchResult.enumerateObjects { asset, index, stop in
            if index < limit {
                photos.append(asset)
            } else {
                stop.pointee = true
            }
        }
        
        return photos
    }
    
    private func preheatThumbnails(for assets: [PHAsset]) async {
        guard !assets.isEmpty else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        
        // 分批预热
        let batches = stride(from: 0, to: assets.count, by: preheatBatchSize).map {
            Array(assets[$0..<min($0 + preheatBatchSize, assets.count)])
        }
        
        for batch in batches {
            cachingManager.startCachingImages(
                for: batch,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: options
            )
        }
        
        print("📦 相册预热：已预热 \(assets.count) 张缩略图")
    }
    
    /// 同步预热缩略图（不等待完成）
    private func preheatThumbnailsSync(for assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        
        // 直接调用，不等待
        cachingManager.startCachingImages(
            for: assets,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        )
        
        print("📦 相册预热：启动 \(assets.count) 张缩略图预热")
    }
    
    private func localizedAlbumTitle(_ collection: PHAssetCollection) -> String {
        let prefersChinese = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
        
        if prefersChinese {
            switch collection.assetCollectionSubtype {
            case .smartAlbumUserLibrary: return "所有照片"
            case .smartAlbumRecentlyAdded: return "最近项目"
            case .smartAlbumFavorites: return "个人收藏"
            case .smartAlbumScreenshots: return "截屏"
            case .smartAlbumSelfPortraits: return "自拍"
            case .smartAlbumPanoramas: return "全景照片"
            default: break
            }
        }
        
        return collection.localizedTitle ?? (prefersChinese ? "相册" : "Album")
    }
}

/// 预热的相册信息
struct PreheatedAlbumInfo {
    let id: String
    let collection: PHAssetCollection
    let title: String
    let count: Int
}

