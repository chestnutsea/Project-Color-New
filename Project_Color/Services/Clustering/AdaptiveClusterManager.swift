//
//  AdaptiveClusterManager.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 5 Stage C: 自适应聚类更新
//

import Foundation
import simd

/// 自适应聚类管理器
/// 负责合并、拆分、删除簇，优化聚类结果
class AdaptiveClusterManager {
    
    private let converter = ColorSpaceConverter()
    private let namer = ColorNameResolver.shared
    private let evaluator = ClusterQualityEvaluator()
    
    // MARK: - 欧几里得距离（与 SimpleKMeans 保持一致）
    /// 在 LAB 空间使用欧几里得距离，将颜色视为 3D 向量 (L, a, b)
    private func euclideanDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diff = a - b
        return sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
    }
    
    // MARK: - Configuration
    
    struct Config {
        /// 合并阈值：两个簇的质心ΔE小于此值时考虑合并
        let mergeThresholdDeltaE: Float
        
        /// 最小簇大小：样本数少于此值的簇将被删除
        let minClusterSize: Int
        
        /// 拆分阈值：簇内平均距离大于此值时考虑拆分
        let splitThresholdIntraDist: Float
        
        /// 是否启用颜色名称相似性检查
        let useColorNameSimilarity: Bool
        
        static let `default` = Config(
            mergeThresholdDeltaE: 12.0,  // ΔE < 12 认为颜色接近（更严格）
            minClusterSize: 1,            // 至少1张照片（保留所有非空簇）
            splitThresholdIntraDist: 40.0, // 簇内平均距离 > 40 考虑拆分
            useColorNameSimilarity: true  // 启用名称相似性检查
        )
    }
    
    // MARK: - Update Result
    
    struct UpdateResult {
        var mergedCount: Int = 0
        var deletedCount: Int = 0
        var splitCount: Int = 0
        var finalClusterCount: Int = 0
        var operations: [String] = []
        
        mutating func addOperation(_ op: String) {
            operations.append(op)
            print("  🔄 \(op)")
        }
    }
    
    // MARK: - Main Update Method
    
    /// 自适应更新聚类
    /// - Parameters:
    ///   - clusters: 现有簇
    ///   - photoInfos: 照片信息（用于重新分配）
    ///   - allColorsLAB: 所有主色点（LAB空间）
    ///   - config: 配置参数
    /// - Returns: 更新后的簇和更新结果
    func updateClusters(
        clusters: [ColorCluster],
        photoInfos: [PhotoColorInfo],
        allColorsLAB: [SIMD3<Float>],
        config: Config = .default
    ) -> (updatedClusters: [ColorCluster], result: UpdateResult) {
        
        print("\n🔄 ========== 自适应聚类更新 ==========")
        print("   初始簇数: \(clusters.count)")
        print("   配置:")
        print("     - 合并阈值 ΔE: \(config.mergeThresholdDeltaE)")
        print("     - 最小簇大小: \(config.minClusterSize)")
        print("     - 拆分阈值: \(config.splitThresholdIntraDist)")
        
        var result = UpdateResult()
        var workingClusters = clusters
        
        // Step 1: 删除小簇
        let (afterDelete, deleteResult) = deleteSmallClusters(
            clusters: workingClusters,
            photoInfos: photoInfos,
            config: config
        )
        workingClusters = afterDelete
        result.deletedCount = deleteResult.count
        for op in deleteResult {
            result.addOperation(op)
        }
        
        // Step 2: 合并相似簇
        let (afterMerge, mergeResult) = mergeSimilarClusters(
            clusters: workingClusters,
            config: config
        )
        workingClusters = afterMerge
        result.mergedCount = mergeResult.count
        for op in mergeResult {
            result.addOperation(op)
        }
        
        // Step 3: 拆分离散簇（可选，较复杂）
        // 暂时跳过，未来可实现
        
        // Step 4: 重新分配照片到更新后的簇
        let finalClusters = reassignPhotos(
            clusters: workingClusters,
            photoInfos: photoInfos
        )
        
        result.finalClusterCount = finalClusters.count
        
        print("\n✅ 自适应更新完成:")
        print("   - 删除: \(result.deletedCount) 个簇")
        print("   - 合并: \(result.mergedCount) 对簇")
        print("   - 拆分: \(result.splitCount) 个簇")
        print("   - 最终: \(result.finalClusterCount) 个簇")
        print("==========================================\n")
        
        return (finalClusters, result)
    }
    
    // MARK: - Step 1: Delete Small Clusters
    
    /// 删除样本数过少的簇
    private func deleteSmallClusters(
        clusters: [ColorCluster],
        photoInfos: [PhotoColorInfo],
        config: Config
    ) -> (clusters: [ColorCluster], operations: [String]) {
        
        var operations: [String] = []
        
        let filtered = clusters.filter { cluster in
            if cluster.photoCount < config.minClusterSize {
                operations.append("删除簇 #\(cluster.index) (\(cluster.colorName)): 仅 \(cluster.photoCount) 张照片")
                return false
            }
            return true
        }
        
        if filtered.isEmpty {
            operations.removeAll()
            operations.append("⚠️ 所有簇都小于最小簇大小，保留原始簇以避免空结果")
            return (clusters, operations)
        }
        
        // 重新索引簇（关键！防止索引越界）
        var reindexed = filtered
        for i in 0..<reindexed.count {
            reindexed[i].index = i
        }
        
        return (reindexed, operations)
    }
    
    // MARK: - Step 2: Merge Similar Clusters
    
    /// 合并相似的簇
    private func mergeSimilarClusters(
        clusters: [ColorCluster],
        config: Config
    ) -> (clusters: [ColorCluster], operations: [String]) {
        
        var operations: [String] = []
        var workingClusters = clusters
        var merged = Set<Int>() // 记录已合并的簇索引
        
        // 将簇质心转换为 LAB
        var centroidsLAB: [Int: SIMD3<Float>] = [:]
        for cluster in workingClusters {
            centroidsLAB[cluster.index] = converter.rgbToLab(cluster.centroid)
        }
        
        // 遍历所有簇对，寻找可合并的
        for i in 0..<workingClusters.count {
            if merged.contains(workingClusters[i].index) {
                continue
            }
            
            for j in (i + 1)..<workingClusters.count {
                if merged.contains(workingClusters[j].index) {
                    continue
                }
                
                let cluster1 = workingClusters[i]
                let cluster2 = workingClusters[j]
                
                guard let lab1 = centroidsLAB[cluster1.index],
                      let lab2 = centroidsLAB[cluster2.index] else {
                    continue
                }
                
                // 计算色差（使用欧几里得距离，与聚类保持一致）
                let distance = euclideanDistance(lab1, lab2)
                
                // 判断是否应该合并
                var shouldMerge = distance < config.mergeThresholdDeltaE
                
                // 如果启用颜色名称相似性检查
                if config.useColorNameSimilarity && shouldMerge {
                    shouldMerge = areColorNamesSimilar(cluster1.colorName, cluster2.colorName)
                }
                
                if shouldMerge {
                    // 合并簇
                    let mergedCluster = mergeTwo(cluster1: cluster1, cluster2: cluster2)
                    
                    // 更新工作列表
                    workingClusters = workingClusters.filter { $0.index != cluster2.index }
                    if let idx = workingClusters.firstIndex(where: { $0.index == cluster1.index }) {
                        workingClusters[idx] = mergedCluster
                    }
                    
                    // 更新质心LAB
                    centroidsLAB[cluster1.index] = converter.rgbToLab(mergedCluster.centroid)
                    centroidsLAB.removeValue(forKey: cluster2.index)
                    
                    merged.insert(cluster2.index)
                    
                    operations.append("合并簇 #\(cluster1.index) (\(cluster1.colorName)) + #\(cluster2.index) (\(cluster2.colorName)) → \(mergedCluster.colorName) (距离=\(String(format: "%.1f", distance)))")
                }
            }
        }
        
        // 重新索引簇（关键！防止索引越界）
        var reindexed = workingClusters
        for i in 0..<reindexed.count {
            reindexed[i].index = i
        }
        
        return (reindexed, operations)
    }
    
    /// 合并两个簇
    private func mergeTwo(cluster1: ColorCluster, cluster2: ColorCluster) -> ColorCluster {
        // 计算新的质心（按照片数加权平均）
        let totalCount = cluster1.photoCount + cluster2.photoCount
        let weight1 = Float(cluster1.photoCount) / Float(totalCount)
        let weight2 = Float(cluster2.photoCount) / Float(totalCount)
        
        let newCentroid = cluster1.centroid * weight1 + cluster2.centroid * weight2
        
        // 重新命名
        let newCentroidLAB = converter.rgbToLab(newCentroid)
        let newName = namer.getColorName(lab: newCentroidLAB)
        
        // 合并照片ID列表
        let combinedPhotos = cluster1.photoIdentifiers + cluster2.photoIdentifiers
        
        return ColorCluster(
            index: cluster1.index,  // 保留第一个簇的索引
            centroid: newCentroid,
            colorName: newName,
            photoCount: totalCount,
            photoIdentifiers: combinedPhotos
        )
    }
    
    /// 判断两个颜色名称是否相似
    private func areColorNamesSimilar(_ name1: String, _ name2: String) -> Bool {
        let lowered1 = name1.lowercased()
        let lowered2 = name2.lowercased()
        
        // 如果完全相同
        if lowered1 == lowered2 {
            return true
        }
        
        // 提取基础颜色名（去掉修饰词）
        let baseColors = ["red", "green", "blue", "yellow", "purple", "orange", 
                         "pink", "brown", "gray", "grey", "white", "black",
                         "cyan", "magenta", "violet", "indigo", "teal"]
        
        var base1: String? = nil
        var base2: String? = nil
        
        for baseColor in baseColors {
            if lowered1.contains(baseColor) {
                base1 = baseColor
            }
            if lowered2.contains(baseColor) {
                base2 = baseColor
            }
        }
        
        // 如果基础颜色相同，认为相似
        if let base1 = base1, let base2 = base2 {
            return base1 == base2
        }
        
        return false
    }
    
    // MARK: - Step 3: Split Dispersed Clusters (Future)
    
    /// 拆分离散的簇（未来实现）
    /// 当簇内距离过大时，可能需要拆分为多个簇
    private func splitDispersedClusters(
        clusters: [ColorCluster],
        allColorsLAB: [SIMD3<Float>],
        config: Config
    ) -> (clusters: [ColorCluster], operations: [String]) {
        // TODO: Phase 6 实现
        // 1. 计算簇内平均距离
        // 2. 如果 > splitThresholdIntraDist，重新对该簇的点运行 KMeans (k=2)
        // 3. 创建两个新簇
        return (clusters, [])
    }
    
    // MARK: - Step 4: Reassign Photos
    
    /// 重新分配照片到更新后的簇
    private func reassignPhotos(
        clusters: [ColorCluster],
        photoInfos: [PhotoColorInfo]
    ) -> [ColorCluster] {
        
        var updatedClusters = clusters
        
        // 重置每个簇的照片列表
        for i in 0..<updatedClusters.count {
            updatedClusters[i].photoIdentifiers = []
            updatedClusters[i].photoCount = 0
        }
        
        // 将簇索引映射到数组索引
        var indexMap: [Int: Int] = [:]
        for (arrayIndex, cluster) in updatedClusters.enumerated() {
            indexMap[cluster.index] = arrayIndex
        }
        
        // 转换簇质心到 LAB 空间
        var centroidsLAB: [SIMD3<Float>] = []
        for cluster in updatedClusters {
            centroidsLAB.append(converter.rgbToLab(cluster.centroid))
        }
        
        // 为每张照片重新分配簇
        for photoInfo in photoInfos {
            var assignedIndex: Int? = nil
            
            // 尝试使用原有的簇索引
            if let primaryClusterIndex = photoInfo.primaryClusterIndex,
               let arrayIndex = indexMap[primaryClusterIndex] {
                assignedIndex = arrayIndex
            } else {
                // 原簇不存在（被删除或合并），需要重新分配
                // 找到最近的簇
                var minDistance = Float.greatestFiniteMagnitude
                var closestClusterIndex = 0
                
                for dominantColor in photoInfo.dominantColors {
                    let colorLAB = converter.rgbToLab(dominantColor.rgb)
                    
                    for (index, centroidLAB) in centroidsLAB.enumerated() {
                        let distance = euclideanDistance(colorLAB, centroidLAB)
                        if distance < minDistance {
                            minDistance = distance
                            closestClusterIndex = index
                        }
                    }
                }
                
                assignedIndex = closestClusterIndex
                print("  🔄 重新分配照片 \(photoInfo.assetIdentifier.prefix(8))... → 簇 #\(updatedClusters[closestClusterIndex].index)")
            }
            
            // 分配照片到簇
            if let arrayIndex = assignedIndex {
                updatedClusters[arrayIndex].photoIdentifiers.append(photoInfo.assetIdentifier)
                updatedClusters[arrayIndex].photoCount += 1
            }
        }
        
        return updatedClusters
    }
    
    // MARK: - Helper: Calculate Intra-Cluster Distance
    
    /// 计算簇内平均距离（用于判断是否需要拆分）
    func calculateIntraClusterDistance(
        clusterCentroidLAB: SIMD3<Float>,
        pointsLAB: [SIMD3<Float>]
    ) -> Float {
        guard !pointsLAB.isEmpty else { return 0.0 }
        
        var totalDistance: Float = 0.0
        
        for point in pointsLAB {
            let distance = euclideanDistance(point, clusterCentroidLAB)
            totalDistance += distance
        }
        
        return totalDistance / Float(pointsLAB.count)
    }
}

