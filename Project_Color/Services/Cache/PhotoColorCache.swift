//
//  PhotoColorCache.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 5 Stage D: 颜色分析缓存
//

import Foundation
import CoreData
import Photos
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

/// 照片颜色分析缓存管理器
/// 利用Core Data存储的PhotoAnalysisEntity作为缓存层
class PhotoColorCache {
    
    private let coreDataManager = CoreDataManager.shared
    
    // MARK: - Check Cache
    
    /// 检查照片是否已缓存分析结果
    /// - Parameter asset: PHAsset
    /// - Returns: 缓存的PhotoColorInfo，如果不存在返回nil
    func getCachedAnalysis(for asset: PHAsset) -> PhotoColorInfo? {
        // 方案1: 使用localIdentifier查询
        // 注意：localIdentifier在照片编辑后会变化，所以不够可靠
        
        // 方案2: 使用SHA256哈希（需要先加载图片）
        // 这里我们暂时使用localIdentifier，因为计算哈希需要加载图片
        
        let identifier = asset.localIdentifier
        
        // 从Core Data查询
        let context = coreDataManager.viewContext
        let fetchRequest = PhotoAnalysisEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier == %@", identifier)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            
            if let entity = results.first,
               let dominantColorsData = entity.dominantColors,
               let dominantColors = try? JSONDecoder().decode([DominantColor].self, from: dominantColorsData) {
                
                print("  ✅ 缓存命中: \(identifier)")
                
                var photoInfo = PhotoColorInfo(
                    assetIdentifier: identifier,
                    dominantColors: dominantColors,
                    primaryClusterIndex: nil,  // 不缓存聚类结果
                    clusterMix: [:]
                )
                
                // 复用 brightnessCDF
                if let cdfData = entity.brightnessCDF {
                    let cdfArray = cdfData.withUnsafeBytes { ptr in
                        Array(ptr.bindMemory(to: Float.self))
                    }
                    photoInfo.brightnessCDF = cdfArray
                    print("  📊 复用 brightnessCDF: \(cdfArray.count) 个值")
                }
                
                // 复用明度中位数和对比度
                let median = entity.brightnessMedian
                let contrast = entity.brightnessContrast
                if median != 0 || contrast != 0 {
                    photoInfo.brightnessMedian = median
                    photoInfo.brightnessContrast = contrast
                    print("  📊 复用明度统计: 中位数=\(median), 对比度=\(contrast)")
                } else if photoInfo.brightnessCDF != nil {
                    // 如果有 CDF 但没有统计值，重新计算
                    photoInfo.computeBrightnessStatistics()
                    print("  📊 从 CDF 重新计算明度统计")
                }
                
                // 复用 AdvancedColorAnalysis（包含冷暖评分、色偏等）
                if let analysisData = entity.advancedColorAnalysisData,
                   let analysis = try? JSONDecoder().decode(AdvancedColorAnalysis.self, from: analysisData) {
                    photoInfo.advancedColorAnalysis = analysis
                    print("  🌡️ 复用冷暖评分: \(String(format: "%.3f", analysis.overallScore))")
                }
                
                // 复用 Vision 信息
                if let visionData = entity.visionInfo,
                   let vision = try? JSONDecoder().decode(PhotoVisionInfo.self, from: visionData) {
                    photoInfo.visionInfo = vision
                    print("  🔍 复用 Vision 信息")
                }
                
                return photoInfo
            }
        } catch {
            print("  ⚠️ 缓存查询失败: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Batch Check
    
    /// 批量检查哪些照片需要重新分析
    /// - Parameter assets: PHAsset数组
    /// - Returns: (需要分析的assets, 缓存的PhotoColorInfo)
    func filterUncached(assets: [PHAsset]) -> (uncached: [PHAsset], cached: [PhotoColorInfo]) {
        var uncached: [PHAsset] = []
        var cached: [PhotoColorInfo] = []
        
        print("\n🔍 检查照片缓存...")
        print("   总数: \(assets.count) 张")
        
        for asset in assets {
            if let cachedInfo = getCachedAnalysis(for: asset) {
                cached.append(cachedInfo)
            } else {
                uncached.append(asset)
            }
        }
        
        print("   ✅ 缓存: \(cached.count) 张")
        print("   ⚠️ 需要处理: \(uncached.count) 张")
        
        return (uncached, cached)
    }
    
    // MARK: - SHA256 Hash (Optional)
    
    /// 计算图片的SHA256哈希
    /// - Parameter asset: PHAsset
    /// - Returns: SHA256哈希字符串，失败返回nil
    func calculateSHA256(for asset: PHAsset) async -> String? {
        #if canImport(UIKit)
        return await withCheckedContinuation { continuation in
            var hasResumed = false  // ✅ 防止重复 resume
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            // 请求原图（用于计算哈希）
            manager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                guard !hasResumed else { return }
                hasResumed = true
                
                guard let data = data else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let hash = SHA256.hash(data: data)
                let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                continuation.resume(returning: hashString)
            }
        }
        #else
        return nil
        #endif
    }
    
    // MARK: - Cache Management
    
    /// 清理孤立的缓存（对应的照片已被删除）
    func cleanOrphanedCache() {
        // TODO: Phase 6 实现
        // 1. 获取所有PhotoAnalysisEntity的assetLocalIdentifier
        // 2. 检查对应的PHAsset是否还存在
        // 3. 删除不存在的记录
    }
    
    /// 清空所有缓存
    func clearAllCache() {
        let context = coreDataManager.viewContext
        let fetchRequest = PhotoAnalysisEntity.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            for entity in results {
                context.delete(entity)
            }
            try context.save()
            print("✅ 已清空所有照片分析缓存")
        } catch {
            print("❌ 清空缓存失败: \(error)")
        }
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> (count: Int, totalSize: Int64) {
        let context = coreDataManager.viewContext
        let fetchRequest = PhotoAnalysisEntity.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            let count = results.count
            
            // 估算大小（每条记录约1KB）
            let estimatedSize = Int64(count) * 1024
            
            return (count, estimatedSize)
        } catch {
            return (0, 0)
        }
    }
}

