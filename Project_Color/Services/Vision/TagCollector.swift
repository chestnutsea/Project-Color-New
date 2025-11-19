//
//  TagCollector.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/18.
//  收集 Vision 返回的所有标签（去重 + 频率统计 + Core Data 持久化）
//

import Foundation
import CoreData

/// 标签来源
enum TagSource: String, Codable {
    case sceneClassification = "Scene"
    case imageClassification = "Image"
    case objectRecognition = "Object"
}

/// 标签统计信息
struct TagStat: Identifiable {
    let id: String
    let tag: String
    let count: Int
    let source: TagSource
    let confidenceMean: Double
    let confidenceMax: Double
    let confidenceMin: Double
    let confidenceVariance: Double
}

/// 内部统计数据（用于 Welford 算法）
private struct ConfidenceStats {
    var count: Int = 0
    var mean: Double = 0.0
    var m2: Double = 0.0  // Welford 算法的 M2 值（用于计算方差）
    var max: Double = 0.0
    var min: Double = 1.0
    
    var variance: Double {
        return count > 1 ? m2 / Double(count) : 0.0
    }
    
    /// 使用 Welford 算法更新统计数据
    mutating func update(with confidence: Double) {
        count += 1
        let delta = confidence - mean
        mean += delta / Double(count)
        let delta2 = confidence - mean
        m2 += delta * delta2
        
        // 更新最大最小值
        max = Swift.max(max, confidence)
        min = Swift.min(min, confidence)
    }
}

final class TagCollector {
    static let shared = TagCollector()
    
    // 使用复合键：tag + source
    private var tagStats: [String: ConfidenceStats] = [:]  // "tag|source" -> 统计数据
    private let queue = DispatchQueue(label: "tag.collector.queue")
    private let coreDataManager = CoreDataManager.shared

    private init() {
        // 从 Core Data 加载数据
        loadFromCoreData()
    }
    
    /// 生成复合键
    private func makeKey(tag: String, source: TagSource) -> String {
        return "\(tag)|\(source.rawValue)"
    }
    
    /// 解析复合键
    private func parseKey(_ key: String) -> (tag: String, source: TagSource)? {
        let parts = key.split(separator: "|")
        guard parts.count == 2,
              let source = TagSource(rawValue: String(parts[1])) else {
            return nil
        }
        return (String(parts[0]), source)
    }

    /// 添加单个标签（带来源和置信度）
    func add(_ tag: String, source: TagSource, confidence: Double = 0.0) {
        let clean = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let key = makeKey(tag: clean, source: source)
        
        queue.sync {
            var stats = tagStats[key] ?? ConfidenceStats()
            stats.update(with: confidence)
            tagStats[key] = stats
        }
        
        // 异步保存到 Core Data
        saveTagToCoreDataAsync(tag: clean, source: source)
    }

    /// 添加多个标签（带来源和置信度）
    func addMultiple(_ tags: [(tag: String, confidence: Double)], source: TagSource) {
        var tagsToSave: [(String, TagSource)] = []
        queue.sync {
            for item in tags {
                let clean = item.tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { continue }
                let key = makeKey(tag: clean, source: source)
                
                var stats = tagStats[key] ?? ConfidenceStats()
                stats.update(with: item.confidence)
                tagStats[key] = stats
                
                tagsToSave.append((clean, source))
            }
        }
        // 批量保存到 Core Data
        saveTagsToCoreDataAsync(tags: tagsToSave)
    }

    /// 导出所有标签（按字母排序）- 已废弃
    func export() -> [String] {
        queue.sync {
            return tagStats.compactMap { parseKey($0.key)?.tag }.sorted()
        }
    }
    
    /// 导出标签统计（按置信度均值倒序）
    func exportStats() -> [TagStat] {
        queue.sync {
            return tagStats.compactMap { key, stats -> TagStat? in
                guard let (tag, source) = parseKey(key) else { return nil }
                return TagStat(
                    id: key,
                    tag: tag,
                    count: stats.count,
                    source: source,
                    confidenceMean: stats.mean,
                    confidenceMax: stats.max,
                    confidenceMin: stats.min,
                    confidenceVariance: stats.variance
                )
            }
            .sorted { $0.confidenceMean > $1.confidenceMean }  // 按置信度均值倒序
        }
    }
    
    /// 按来源导出标签统计
    func exportStatsBySource() -> [TagSource: [TagStat]] {
        queue.sync {
            var result: [TagSource: [TagStat]] = [:]
            for (key, stats) in tagStats {
                guard let (tag, source) = parseKey(key) else { continue }
                let stat = TagStat(
                    id: key,
                    tag: tag,
                    count: stats.count,
                    source: source,
                    confidenceMean: stats.mean,
                    confidenceMax: stats.max,
                    confidenceMin: stats.min,
                    confidenceVariance: stats.variance
                )
                result[source, default: []].append(stat)
            }
            // 对每个来源的标签按置信度均值倒序排序
            for source in result.keys {
                result[source]?.sort { $0.confidenceMean > $1.confidenceMean }
            }
            return result
        }
    }
    
    /// 获取标签数量（去重后）
    func count() -> Int {
        queue.sync {
            return tagStats.count
        }
    }
    
    /// 获取总标签数（包含重复）
    func totalCount() -> Int {
        queue.sync {
            return tagStats.values.reduce(0) { $0 + $1.count }
        }
    }
    
    /// 清空所有标签
    func clear() {
        queue.sync {
            tagStats.removeAll()
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
                    if let tag = entity.tag,
                       let sourceString = entity.source,
                       let source = TagSource(rawValue: sourceString) {
                        let key = makeKey(tag: tag, source: source)
                        
                        // 从 Core Data 恢复统计数据
                        var stats = ConfidenceStats()
                        stats.count = Int(entity.count)
                        stats.mean = entity.confidenceMean
                        stats.max = entity.confidenceMax
                        stats.min = entity.confidenceMin
                        
                        // 从方差反推 m2（用于后续 Welford 更新）
                        stats.m2 = entity.confidenceVariance * Double(stats.count)
                        
                        tagStats[key] = stats
                    }
                }
            }
            print("✅ 从 Core Data 加载了 \(entities.count) 个标签")
        } catch {
            print("❌ 加载标签失败: \(error.localizedDescription)")
        }
    }
    
    /// 异步保存单个标签到 Core Data
    private func saveTagToCoreDataAsync(tag: String, source: TagSource) {
        let key = makeKey(tag: tag, source: source)
        let stats = queue.sync { tagStats[key] }
        guard let stats = stats else { return }
        
        coreDataManager.performBackgroundTask { context in
            // 查找是否已存在（tag + source 作为复合键）
            let request = VisionTagEntity.fetchRequest()
            request.predicate = NSPredicate(format: "tag == %@ AND source == %@", tag, source.rawValue)
            request.fetchLimit = 1
            
            do {
                if let existingEntity = try context.fetch(request).first {
                    // 更新现有记录
                    existingEntity.count = Int32(stats.count)
                    existingEntity.confidenceMean = stats.mean
                    existingEntity.confidenceMax = stats.max
                    existingEntity.confidenceMin = stats.min
                    existingEntity.confidenceVariance = stats.variance
                    existingEntity.lastUpdated = Date()
                } else {
                    // 创建新记录
                    let entity = VisionTagEntity(context: context)
                    entity.id = UUID()
                    entity.tag = tag
                    entity.source = source.rawValue
                    entity.count = Int32(stats.count)
                    entity.confidenceMean = stats.mean
                    entity.confidenceMax = stats.max
                    entity.confidenceMin = stats.min
                    entity.confidenceVariance = stats.variance
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
    private func saveTagsToCoreDataAsync(tags: [(String, TagSource)]) {
        guard !tags.isEmpty else { return }
        
        let statsDict = queue.sync {
            tags.reduce(into: [String: ConfidenceStats]()) { result, item in
                let key = makeKey(tag: item.0, source: item.1)
                result[key] = tagStats[key]
            }
        }
        
        coreDataManager.performBackgroundTask { [weak self] context in
            guard let self = self else { return }
            for (tag, source) in tags {
                let key = self.makeKey(tag: tag, source: source)
                guard let stats = statsDict[key] else { continue }
                
                // 查找是否已存在（tag + source 作为复合键）
                let request = VisionTagEntity.fetchRequest()
                request.predicate = NSPredicate(format: "tag == %@ AND source == %@", tag, source.rawValue)
                request.fetchLimit = 1
                
                do {
                    if let existingEntity = try context.fetch(request).first {
                        // 更新现有记录
                        existingEntity.count = Int32(stats.count)
                        existingEntity.confidenceMean = stats.mean
                        existingEntity.confidenceMax = stats.max
                        existingEntity.confidenceMin = stats.min
                        existingEntity.confidenceVariance = stats.variance
                        existingEntity.lastUpdated = Date()
                    } else {
                        // 创建新记录
                        let entity = VisionTagEntity(context: context)
                        entity.id = UUID()
                        entity.tag = tag
                        entity.source = source.rawValue
                        entity.count = Int32(stats.count)
                        entity.confidenceMean = stats.mean
                        entity.confidenceMax = stats.max
                        entity.confidenceMin = stats.min
                        entity.confidenceVariance = stats.variance
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

