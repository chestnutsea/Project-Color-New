//
//  PhotoSelectionManager.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//

import SwiftUI
import Photos
import Combine

// MARK: - 相册选择管理器
class PhotoSelectionManager: ObservableObject {
    static let shared = PhotoSelectionManager()
    
    @Published var selectedAlbums: [Album] = []
    
    private init() {}
    
    // 切换相册选择状态
    func toggleAlbumSelection(_ album: Album) {
        if let index = selectedAlbums.firstIndex(where: { $0.id == album.id }) {
            selectedAlbums.remove(at: index)
        } else {
            selectedAlbums.append(album)
        }
    }
    
    // 检查相册是否被选中
    func isAlbumSelected(_ album: Album) -> Bool {
        return selectedAlbums.contains(where: { $0.id == album.id })
    }
    
    // 清除所有选择
    func clearSelection() {
        selectedAlbums.removeAll()
    }
    
    // 从选中的相册获取最新的 N 张照片（去重）
    func getLatestPhotos(count: Int) -> [PHAsset] {
        var allAssets: [PHAsset] = []
        var assetIds = Set<String>() // 用于去重
        
        for album in selectedAlbums {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult: PHFetchResult<PHAsset>
            if let collection = album.assetCollection {
                fetchResult = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            } else {
                // "全部"相册
                fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            }
            
            fetchResult.enumerateObjects { asset, _, _ in
                // 只添加不重复的照片
                if !assetIds.contains(asset.localIdentifier) {
                    allAssets.append(asset)
                    assetIds.insert(asset.localIdentifier)
                }
            }
        }
        
        // 按创建时间排序，获取最新的 N 张
        let sorted = allAssets.sorted { asset1, asset2 in
            guard let date1 = asset1.creationDate, let date2 = asset2.creationDate else {
                return false
            }
            return date1 > date2
        }
        
        return Array(sorted.prefix(count))
    }
}

