//
//  TagCollector.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/18.
//  收集 Vision 返回的所有标签（去重 + 频率统计 + Core Data 持久化）
//

import Foundation
import CoreData

/// 标签统计信息
struct TagStat: Identifiable {
    let id: String
    let tag: String
    let count: Int
}

final class TagCollector {
    static let shared = TagCollector()
    
    private var tagCounts: [String: Int] = [:]  // 标签 -> 出现次数
    private let queue = DispatchQueue(label: "tag.collector.queue")
    private let coreDataManager = CoreDataManager.shared

    private init() {
        // 从 Core Data 加载数据
        loadFromCoreData()
    }

    /// 添加单个标签
    func add(_ tag: String) {
        let clean = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        queue.sync {
            tagCounts[clean, default: 0] += 1
        }
        // 异步保存到 Core Data
        saveTagToCoreDataAsync(tag: clean)
    }

    /// 添加多个标签
    func addMultiple(_ tags: [String]) {
        var tagsToSave: [String] = []
        queue.sync {
            for tag in tags {
                let clean = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { continue }
                tagCounts[clean, default: 0] += 1
                tagsToSave.append(clean)
            }
        }
        // 批量保存到 Core Data
        saveTagsToCoreDataAsync(tags: tagsToSave)
    }

    /// 导出所有标签（按字母排序）
    func export() -> [String] {
        queue.sync {
            return Array(tagCounts.keys).sorted()
        }
    }
    
    /// 导出标签统计（按次数倒序）
    func exportStats() -> [TagStat] {
        queue.sync {
            return tagCounts.map { TagStat(id: $0.key, tag: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }  // 按次数倒序
        }
    }
    
    /// 获取标签数量（去重后）
    func count() -> Int {
        queue.sync {
            return tagCounts.count
        }
    }
    
    /// 获取总标签数（包含重复）
    func totalCount() -> Int {
        queue.sync {
            return tagCounts.values.reduce(0, +)
        }
    }
    
    /// 清空所有标签
    func clear() {
        queue.sync {
            tagCounts.removeAll()
            clearCoreData()
        }
    }
    
    // MARK: - Core Data 持久化
    
    /// 从 Core Data 加载标签数据
    private func loadFromCoreData() {
        let context = coreDataManager.viewContext
        let request = VisionTagEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(request)
            queue.sync {
                for entity in entities {
                    if let tag = entity.tag {
                        tagCounts[tag] = Int(entity.count)
                    }
                }
            }
            print("✅ 从 Core Data 加载了 \(entities.count) 个标签")
        } catch {
            print("❌ 加载标签失败: \(error.localizedDescription)")
        }
    }
    
    /// 异步保存单个标签到 Core Data
    private func saveTagToCoreDataAsync(tag: String) {
        let count = queue.sync { tagCounts[tag] ?? 0 }
        
        coreDataManager.performBackgroundTask { context in
            // 查找是否已存在
            let request = VisionTagEntity.fetchRequest()
            request.predicate = NSPredicate(format: "tag == %@", tag)
            request.fetchLimit = 1
            
            do {
                if let existingEntity = try context.fetch(request).first {
                    // 更新现有记录
                    existingEntity.count = Int32(count)
                    existingEntity.lastUpdated = Date()
                } else {
                    // 创建新记录
                    let entity = VisionTagEntity(context: context)
                    entity.id = UUID()
                    entity.tag = tag
                    entity.count = Int32(count)
                    entity.lastUpdated = Date()
                }
                
                // 保存上下文
                try context.save()
            } catch {
                print("❌ 保存标签失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 批量保存标签到 Core Data
    private func saveTagsToCoreDataAsync(tags: [String]) {
        guard !tags.isEmpty else { return }
        
        let counts = queue.sync {
            tags.reduce(into: [String: Int]()) { result, tag in
                result[tag] = tagCounts[tag] ?? 0
            }
        }
        
        coreDataManager.performBackgroundTask { context in
            for tag in tags {
                let count = counts[tag] ?? 0
                
                // 查找是否已存在
                let request = VisionTagEntity.fetchRequest()
                request.predicate = NSPredicate(format: "tag == %@", tag)
                request.fetchLimit = 1
                
                do {
                    if let existingEntity = try context.fetch(request).first {
                        // 更新现有记录
                        existingEntity.count = Int32(count)
                        existingEntity.lastUpdated = Date()
                    } else {
                        // 创建新记录
                        let entity = VisionTagEntity(context: context)
                        entity.id = UUID()
                        entity.tag = tag
                        entity.count = Int32(count)
                        entity.lastUpdated = Date()
                    }
                } catch {
                    print("❌ 查询标签失败: \(error.localizedDescription)")
                }
            }
            
            // 批量保存
            do {
                try context.save()
            } catch {
                print("❌ 批量保存标签失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 清空 Core Data 中的所有标签
    private func clearCoreData() {
        let context = coreDataManager.viewContext
        let request = VisionTagEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
            print("✅ 已清空 Core Data 中的所有标签")
        } catch {
            print("❌ 清空标签失败: \(error.localizedDescription)")
        }
    }
}

