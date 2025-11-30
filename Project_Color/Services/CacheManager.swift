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
        
        Task.detached(priority: .background) {
            print("🔥 缓存预热：开始...")
            let startTime = Date()
            
            // 1. 获取所有分析会话的封面图 ID
            let coverAssetIds = await self.fetchCoverAssetIds()
            
            // 2. 预加载封面图
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

