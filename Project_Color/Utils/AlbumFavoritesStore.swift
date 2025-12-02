//
//  AlbumFavoritesStore.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/23.
//

import Foundation

/// 简单的相册收藏持久化（UserDefaults）
final class AlbumFavoritesStore {
    static let shared = AlbumFavoritesStore()
    private let key = "album_favorite_ids"
    private let defaults = UserDefaults.standard
    
    func load() -> Set<String> {
        let ids = defaults.stringArray(forKey: key) ?? []
        print("📌 AlbumFavoritesStore.load(): \(ids)")
        return Set(ids)
    }
    
    func save(_ ids: Set<String>) {
        let array = Array(ids)
        defaults.set(array, forKey: key)
        defaults.synchronize()  // 强制同步
        print("📌 AlbumFavoritesStore.save(): \(array)")
    }
}
