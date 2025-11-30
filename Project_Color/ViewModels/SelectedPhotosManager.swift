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
    
    private var imageRequestID: PHImageRequestID?
    private var loadedAssetIds = Set<String>()  // 跟踪已加载的图片，避免重复
    
    private init() {}
    
    /// 获取选中照片的数量
    var count: Int {
        return selectedAssets.count
    }
    
    /// 是否有选中的照片
    var hasSelection: Bool {
        return !selectedAssets.isEmpty
    }
    
    /// 从 PHPickerResult 更新选中的资产
    func updateSelectedAssets(with results: [PHPickerResult]) {
        print("📸 SelectedPhotosManager: 开始更新资产，收到 \(results.count) 个结果")
        
        // 提取有效的 assetIdentifier 并去重（保持顺序）
        let identifiers = results.compactMap { $0.assetIdentifier }
        let uniqueIdentifiers = deduplicatedIdentifiers(from: identifiers)
        if identifiers.count != uniqueIdentifiers.count {
            print("📸 SelectedPhotosManager: 去除了重复的标识符 \(identifiers.count - uniqueIdentifiers.count) 个")
        }
        print("📸 SelectedPhotosManager: 提取了 \(uniqueIdentifiers.count) 个有效标识符")
        
        // 如果有标识符，使用它们；否则直接加载图片
        if !uniqueIdentifiers.isEmpty {
            selectedAssetIdentifiers = uniqueIdentifiers
            fetchAssets()
        } else {
            // 如果没有 assetIdentifier（可能是从其他来源选择的照片），直接加载图片
            print("📸 SelectedPhotosManager: 没有有效的 assetIdentifier，直接从 itemProvider 加载图片")
            loadImagesFromResults(results)
        }
    }
    
    /// 从 PHPickerResult 直接加载图片（当没有 assetIdentifier 时）
    private func loadImagesFromResults(_ results: [PHPickerResult]) {
        selectedImages.removeAll()
        selectedAssets = []
        selectedAssetIdentifiers = []
        
        let dispatchGroup = DispatchGroup()
        var loadedImages: [UIImage] = []
        
        for result in results.suffix(3) {
            dispatchGroup.enter()
            
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                    defer { dispatchGroup.leave() }
                    
                    if let image = image as? UIImage {
                        loadedImages.append(image)
                    } else if let error = error {
                        print("❌ 加载图片失败: \(error.localizedDescription)")
                    }
                }
            } else {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.selectedImages = loadedImages
            print("📸 SelectedPhotosManager: 从 itemProvider 加载了 \(loadedImages.count) 张图片")
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
    
    /// 清空选中的照片
    func clearSelection() {
        selectedAssetIdentifiers = []
        selectedAssets = []
        selectedImages = []
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
    
    // MARK: - Private Methods
    
    private func fetchAssets() {
        guard !selectedAssetIdentifiers.isEmpty else {
            selectedAssets = []
            selectedImages = []
            print("📸 SelectedPhotosManager: 标识符为空，清空资产")
            return
        }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: selectedAssetIdentifiers, options: nil)
        var fetchedAssets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            fetchedAssets.append(asset)
        }
        
        print("📸 SelectedPhotosManager: 获取了 \(fetchedAssets.count) 个 PHAsset")
        
        // Sort fetched assets to match the order of selectedAssetIdentifiers
        selectedAssets = selectedAssetIdentifiers.compactMap { identifier in
            fetchedAssets.first { $0.localIdentifier == identifier }
        }
        
        print("📸 SelectedPhotosManager: 排序后有 \(selectedAssets.count) 个资产")
        
        loadLatestImages()
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
