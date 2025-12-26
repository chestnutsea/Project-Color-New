//
//  PhotoImageLoader.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/24.
//  处理照片加载的降级逻辑（系统相册 → 缩略图 → 占位图）
//

import UIKit
import Photos
import CoreData

/// 照片图片加载器
class PhotoImageLoader {
    
    /// 照片来源
    enum PhotoSource {
        case systemLibrary    // 从系统相册加载
        case thumbnail        // 使用缓存缩略图
        case placeholder      // 占位图
    }
    
    /// 加载结果
    struct LoadResult {
        let image: UIImage?
        let source: PhotoSource
    }
    
    // MARK: - Public Methods
    
    /// 加载照片图片（带降级逻辑）
    /// - Parameter analysis: PhotoAnalysisEntity 对象
    /// - Returns: 加载结果（图片 + 来源）
    static func loadImage(for analysis: PhotoAnalysisEntity) async -> LoadResult {
        // 1. 尝试从系统相册加载
        if let identifier = analysis.assetLocalIdentifier {
            if let image = await loadFromSystemLibrary(identifier: identifier) {
                return LoadResult(image: image, source: .systemLibrary)
            }
        }
        
        // 2. 降级：使用缓存的缩略图
        if let thumbnailData = analysis.thumbnailData,
           let thumbnail = UIImage(data: thumbnailData) {
            return LoadResult(image: thumbnail, source: .thumbnail)
        }
        
        // 3. 最终降级：返回占位图
        let placeholder = UIImage(systemName: "photo.fill")
        return LoadResult(image: placeholder, source: .placeholder)
    }
    
    /// 同步加载照片图片（用于非异步上下文）
    /// - Parameter analysis: PhotoAnalysisEntity 对象
    /// - Returns: 加载结果（图片 + 来源）
    static func loadImageSync(for analysis: PhotoAnalysisEntity) -> LoadResult {
        // 1. 尝试从系统相册加载（同步）
        if let identifier = analysis.assetLocalIdentifier {
            if let image = loadFromSystemLibrarySync(identifier: identifier) {
                return LoadResult(image: image, source: .systemLibrary)
            }
        }
        
        // 2. 降级：使用缓存的缩略图
        if let thumbnailData = analysis.thumbnailData,
           let thumbnail = UIImage(data: thumbnailData) {
            return LoadResult(image: thumbnail, source: .thumbnail)
        }
        
        // 3. 最终降级：返回占位图
        let placeholder = UIImage(systemName: "photo.fill")
        return LoadResult(image: placeholder, source: .placeholder)
    }
    
    // MARK: - Private Methods
    
    /// 从系统相册加载照片（异步）
    private static func loadFromSystemLibrary(identifier: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            
            guard let asset = fetchResult.firstObject else {
                continuation.resume(returning: nil)
                return
            }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = false  // 不从 iCloud 下载
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    /// 从系统相册加载照片（同步）
    private static func loadFromSystemLibrarySync(identifier: String) -> UIImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        
        guard let asset = fetchResult.firstObject else {
            return nil
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        
        var resultImage: UIImage?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            resultImage = image
        }
        
        return resultImage
    }
    
    /// 检查照片是否在系统相册中可用
    /// - Parameter identifier: 照片的 localIdentifier
    /// - Returns: 是否可用
    static func isPhotoAvailable(identifier: String) -> Bool {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject != nil
    }
}

