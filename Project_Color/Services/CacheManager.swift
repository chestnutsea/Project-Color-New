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

// MARK: - 封面图缓存（内存 + 磁盘双层缓存）

/// 封面图缓存管理器
/// - 内存缓存：NSCache，快速访问，自动内存管理
/// - 磁盘缓存：Caches 目录，持久化存储，App 重启后仍可用
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    // MARK: - 内存缓存
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // MARK: - 磁盘缓存
    private let diskCacheDirectory: URL
    private let ioQueue = DispatchQueue(label: "com.projectcolor.thumbnailcache.io", qos: .utility)
    private let fileManager = FileManager.default
    
    // MARK: - 配置
    private let targetSize = CGSize(width: 300, height: 300)
    private let jpegCompressionQuality: CGFloat = 0.8
    private let maxDiskCacheSize: Int = 100_000_000  // 100MB
    
    private init() {
        // 设置内存缓存限制
        memoryCache.countLimit = 200  // 最多缓存 200 张封面图
        
        // 初始化磁盘缓存目录
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheDirectory = caches.appendingPathComponent("ThumbnailCache", isDirectory: true)
        
        // 创建目录（如果不存在）
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        
        print("📦 ThumbnailCache 初始化完成，磁盘缓存目录: \(diskCacheDirectory.path)")
        
        // 启动时异步清理过期缓存
        ioQueue.async { [weak self] in
            self?.cleanupDiskCacheIfNeeded()
        }
    }
    
    // MARK: - 公开接口
    
    /// 获取缓存的封面图（先查内存，再查磁盘）
    func image(for assetId: String) -> UIImage? {
        // 1. 先查内存缓存
        if let cachedImage = memoryCache.object(forKey: assetId as NSString) {
            return cachedImage
        }
        
        // 2. 再查磁盘缓存
        let fileURL = diskCacheURL(for: assetId)
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // 写回内存缓存
        memoryCache.setObject(image, forKey: assetId as NSString)
        
        return image
    }
    
    /// 缓存封面图（同时写入内存和磁盘）
    func setImage(_ image: UIImage, for assetId: String) {
        // 写入内存缓存
        memoryCache.setObject(image, forKey: assetId as NSString)
        
        // 异步写入磁盘缓存
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.diskCacheURL(for: assetId)
            
            // 使用 JPEG 压缩存储，节省空间
            if let data = image.jpegData(compressionQuality: self.jpegCompressionQuality) {
                do {
                    try data.write(to: fileURL)
                } catch {
                    print("⚠️ 写入磁盘缓存失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 检查磁盘缓存是否存在（不加载图片）
    func hasDiskCache(for assetId: String) -> Bool {
        let fileURL = diskCacheURL(for: assetId)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// 预加载封面图（后台执行，优先从磁盘加载）
    func preloadCovers(assetIds: [String]) async {
        // 分离：已有磁盘缓存的 vs 需要从相册加载的
        var idsToLoadFromDisk: [String] = []
        var idsToLoadFromPhotos: [String] = []
        
        for assetId in assetIds {
            if memoryCache.object(forKey: assetId as NSString) != nil {
                // 已在内存中，跳过
                continue
            } else if hasDiskCache(for: assetId) {
                idsToLoadFromDisk.append(assetId)
            } else {
                idsToLoadFromPhotos.append(assetId)
            }
        }
        
        print("📦 封面图缓存：内存命中 \(assetIds.count - idsToLoadFromDisk.count - idsToLoadFromPhotos.count) 张，磁盘加载 \(idsToLoadFromDisk.count) 张，相册加载 \(idsToLoadFromPhotos.count) 张")
        
        // 1. 从磁盘加载到内存
        for assetId in idsToLoadFromDisk {
            _ = image(for: assetId)  // 这会自动写入内存缓存
        }
        
        // 2. 从相册加载（并写入磁盘）
        guard !idsToLoadFromPhotos.isEmpty else {
            print("✅ 封面图缓存：预加载完成（全部来自缓存）")
            return
        }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: idsToLoadFromPhotos, options: nil)
        
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
                    self.setImage(image, for: asset.localIdentifier)  // 同时写入内存和磁盘
                }
            }
        }
        
        print("✅ 封面图缓存：预加载完成")
    }
    
    /// 清空所有缓存（内存 + 磁盘）
    func clearCache() {
        // 清空内存缓存
        memoryCache.removeAllObjects()
        
        // 清空磁盘缓存
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let files = try self.fileManager.contentsOfDirectory(at: self.diskCacheDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    try self.fileManager.removeItem(at: file)
                }
                print("🗑️ 封面图缓存已清空（内存 + 磁盘）")
            } catch {
                print("⚠️ 清空磁盘缓存失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 清空内存缓存（保留磁盘缓存）
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        print("🗑️ 封面图内存缓存已清空")
    }
    
    /// 获取磁盘缓存大小（字节）
    func getDiskCacheSize() -> Int {
        var totalSize: Int = 0
        ioQueue.sync {
            guard let files = try? fileManager.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
                return
            }
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += size
                }
            }
        }
        return totalSize
    }
    
    // MARK: - 私有方法
    
    /// 生成磁盘缓存文件 URL
    private func diskCacheURL(for assetId: String) -> URL {
        // 使用 assetId 的 SHA256 哈希作为文件名，避免特殊字符问题
        let safeFileName = assetId.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return diskCacheDirectory.appendingPathComponent("\(safeFileName).jpg")
    }
    
    /// 清理磁盘缓存（如果超过限制）
    private func cleanupDiskCacheIfNeeded() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }
        
        // 计算总大小
        var totalSize: Int = 0
        var fileInfos: [(url: URL, size: Int, date: Date)] = []
        
        for file in files {
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize,
                  let date = values.contentModificationDate else { continue }
            totalSize += size
            fileInfos.append((file, size, date))
        }
        
        // 如果未超过限制，不清理
        guard totalSize > maxDiskCacheSize else {
            print("📦 磁盘缓存大小: \(totalSize / 1_000_000)MB，未超过限制 \(maxDiskCacheSize / 1_000_000)MB")
            return
        }
        
        print("⚠️ 磁盘缓存超过限制，开始清理...")
        
        // 按修改日期排序（最旧的在前）
        fileInfos.sort { $0.date < $1.date }
        
        // 删除最旧的文件，直到低于限制的 80%
        let targetSize = maxDiskCacheSize * 8 / 10
        var currentSize = totalSize
        var deletedCount = 0
        
        for fileInfo in fileInfos {
            guard currentSize > targetSize else { break }
            do {
                try fileManager.removeItem(at: fileInfo.url)
                currentSize -= fileInfo.size
                deletedCount += 1
            } catch {
                print("⚠️ 删除缓存文件失败: \(error.localizedDescription)")
            }
        }
        
        print("✅ 磁盘缓存清理完成，删除 \(deletedCount) 个文件，当前大小: \(currentSize / 1_000_000)MB")
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
    private let thumbnailSize = CGSize(width: 300, height: 300)  // 统一为 300，与 ThumbnailCache 一致
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

