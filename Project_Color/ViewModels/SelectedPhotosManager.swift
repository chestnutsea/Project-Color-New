//
//  SelectedPhotosManager.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/23.
//  管理用户选中的照片
//

import Foundation
import Photos
import PhotosUI
import SwiftUI
import Combine

class SelectedPhotosManager: ObservableObject {
    static let shared = SelectedPhotosManager()
    
    @Published var selectedAssetIdentifiers: [String] = []
    @Published var selectedAssets: [PHAsset] = []
    @Published var selectedImages: [UIImage] = []
    @Published var originalImages: [UIImage] = []  // 保存原图（用于全屏查看）
    @Published var selectedMetadata: [PhotoMetadata] = []  // 保存照片元数据（EXIF 信息）
    
    private var imageRequestID: PHImageRequestID?
    private var loadedAssetIds = Set<String>()  // 跟踪已加载的图片，避免重复
    private var lastPickerResults: [PHPickerResult] = []  // 保存最近的选择结果，便于回退加载
    
    private init() {}
    
    /// 获取选中照片的数量
    var count: Int {
        return selectedAssets.count + selectedImages.count
    }
    
    /// 是否有选中的照片
    var hasSelection: Bool {
        return !selectedAssets.isEmpty || !selectedImages.isEmpty
    }
    
    /// 从 PHPickerResult 更新选中的资产
    func updateSelectedAssets(with results: [PHPickerResult]) {
        print("📸 SelectedPhotosManager: 开始更新资产，收到 \(results.count) 个结果")
        lastPickerResults = results
        
        // ✅ 隐私模式：生成 UUID 作为标识符，不使用 assetIdentifier
        // 避免调用 PHAsset.fetchAssets 触发权限弹窗
        let identifiers = results.map { _ in UUID().uuidString }
        print("📸 SelectedPhotosManager: 生成了 \(identifiers.count) 个 UUID 标识符（隐私模式）")
        
        // ✅ 直接从 itemProvider 加载图片，不尝试获取 PHAsset
        print("📸 SelectedPhotosManager: 直接从 itemProvider 加载图片（隐私模式）")
        loadImagesFromResults(results, identifiers: identifiers)
    }
    
    /// 从 PHPickerResult 直接加载图片（隐私模式）
    private func loadImagesFromResults(_ results: [PHPickerResult], identifiers: [String]) {
        selectedImages.removeAll()
        selectedAssets = []
        selectedAssetIdentifiers = identifiers
        
        let dispatchGroup = DispatchGroup()
        var loadedImages: [(index: Int, image: UIImage)] = []  // 保存索引以维持顺序
        
        // ✅ 加载所有照片（用于分析），而不仅仅是最后3张
        for (index, result) in results.enumerated() {
            dispatchGroup.enter()
            
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                    defer { dispatchGroup.leave() }
                    
                    if let image = image as? UIImage {
                        // 收集到数组中，保存索引以维持顺序
                        loadedImages.append((index: index, image: image))
                    } else if let error = error {
                        print("❌ 加载图片失败: \(error.localizedDescription)")
                    }
                }
            } else {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // 按原始顺序排序
            let sortedImages = loadedImages.sorted { $0.index < $1.index }.map { $0.image }
            self.selectedImages = sortedImages
            // 同时保存原图（用于全屏查看）
            self.originalImages = sortedImages
            print("📸 SelectedPhotosManager: 从 itemProvider 加载了 \(sortedImages.count) 张图片（隐私模式）")
        }
    }
    
    /// 获取最新的 N 张照片（按拍摄日期排序）
    /// - Parameter count: 需要获取的照片数量
    /// - Returns: 最新的照片数组
    func getLatestPhotos(count: Int) -> [PHAsset] {
        // 按拍摄日期降序排序
        let sorted = selectedAssets.sorted { asset1, asset2 in
            guard let date1 = asset1.creationDate,
                  let date2 = asset2.creationDate else {
                return false
            }
            return date1 > date2
        }
        
        return Array(sorted.prefix(count))
    }
    
    /// 在需要时重新尝试根据标识符获取 PHAsset（用于权限被延迟授予的情况）
    func refetchAssetsIfNeeded() {
        guard selectedAssets.isEmpty, !selectedAssetIdentifiers.isEmpty else { return }
        print("📸 SelectedPhotosManager: 尝试重新获取 PHAsset...")
        fetchAssets(fallbackResults: lastPickerResults, fallbackIdentifiers: selectedAssetIdentifiers)
    }
    
    /// 清空选中的照片
    func clearSelection() {
        selectedAssetIdentifiers = []
        selectedAssets = []
        selectedImages = []
        selectedMetadata = []
        if let requestID = imageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            imageRequestID = nil
        }
        print("🗑️ 已清空照片选择")
    }
    
    /// 更新选中的照片
    /// - Parameter assets: 新的照片数组
    func updateSelection(_ assets: [PHAsset]) {
        selectedAssets = assets
        selectedAssetIdentifiers = assets.map { $0.localIdentifier }
        print("📸 已更新照片选择: \(assets.count) 张")
        loadLatestImages()
    }
    
    /// 隐私模式：直接使用图片更新选择（不使用 PHAsset）
    /// - Parameters:
    ///   - images: 加载的图片数组
    ///   - identifiers: 照片标识符数组（可以是 assetIdentifier 或 UUID）
    ///   - metadata: 照片元数据数组（可选）
    func updateWithImages(_ images: [UIImage], identifiers: [String], metadata: [PhotoMetadata] = []) {
        // 清空 PHAsset 相关数据
        selectedAssets = []
        
        // 保存标识符（用于去重和追踪）
        selectedAssetIdentifiers = identifiers
        
        // 保存所有图片（用于分析）
        selectedImages = images
        
        // 保存元数据
        selectedMetadata = metadata
        
        print("📸 SelectedPhotosManager: 已更新照片选择（隐私模式）: \(images.count) 张")
        if !metadata.isEmpty {
            print("📸 SelectedPhotosManager: 已保存 \(metadata.count) 张照片的元数据")
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchAssets(fallbackResults: [PHPickerResult]? = nil, fallbackIdentifiers: [String]? = nil) {
        // ⚠️ 已弃用：此方法会触发照片库权限弹窗
        // 在隐私模式下，我们不再使用 PHAsset.fetchAssets
        // 所有照片都通过 PHPickerResult 的 itemProvider 直接加载
        
        print("⚠️ fetchAssets 已弃用（隐私模式），直接使用 loadImagesFromResults")
        
        if let results = fallbackResults {
            loadImagesFromResults(results, identifiers: fallbackIdentifiers ?? selectedAssetIdentifiers)
        } else {
            print("❌ 无法加载图片：没有 fallbackResults")
        }
    }
    
    func loadLatestImages() {
        selectedImages.removeAll()
        loadedAssetIds.removeAll()  // 重置已加载的图片集合
        
        let assetsToLoad = Array(selectedAssets.suffix(3)) // Get the latest 3 for preview
        
        print("📸 SelectedPhotosManager: 开始加载最新 \(assetsToLoad.count) 张图片")
        
        guard !assetsToLoad.isEmpty else {
            print("📸 SelectedPhotosManager: 没有资产需要加载")
            return
        }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        
        // Cancel previous requests if any
        if let requestID = imageRequestID {
            manager.cancelImageRequest(requestID)
        }
        
        let totalCount = assetsToLoad.count
        
        // Load images in reverse order to get the latest 3 efficiently
        for asset in assetsToLoad.reversed() {
            let assetId = asset.localIdentifier
            
            imageRequestID = manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFit,
                options: options
            ) { [weak self] image, info in
                guard let self = self else { return }
                
                // ✅ 检查是否是最终图片（非占位图）
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                
                if let image = image {
                    DispatchQueue.main.async {
                        // ✅ 只有当这个 asset 还没有被添加时才添加
                        if !self.loadedAssetIds.contains(assetId) {
                            self.loadedAssetIds.insert(assetId)
                            self.selectedImages.insert(image, at: 0)
                            print("📸 SelectedPhotosManager: 已加载 \(self.loadedAssetIds.count)/\(totalCount) 张图片 (isDegraded: \(isDegraded))")
                            
                            if self.loadedAssetIds.count == totalCount {
                                self.imageRequestID = nil
                                print("📸 SelectedPhotosManager: 所有图片加载完成，共 \(self.selectedImages.count) 张")
                            }
                        } else {
                            print("📸 SelectedPhotosManager: 跳过重复图片 \(assetId.prefix(8))... (isDegraded: \(isDegraded))")
                        }
                    }
                }
            }
        }
    }

    /// 去重并保持原始顺序
    private func deduplicatedIdentifiers(from identifiers: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        
        for id in identifiers {
            if !seen.contains(id) {
                seen.insert(id)
                result.append(id)
            }
        }
        return result
    }
}
