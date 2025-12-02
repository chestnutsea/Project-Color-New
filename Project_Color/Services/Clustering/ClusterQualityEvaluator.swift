//
//  ClusterQualityEvaluator.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 4: 聚类质量评估（Silhouette Score）
//  Updated: 支持色调模式（只用 a, b 计算距离）和综合模式（L, a, b 计算距离）
//

import Foundation

/// 聚类质量评估器
class ClusterQualityEvaluator {
    
    // MARK: - 距离计算
    
    /// 根据模式计算距离
    private func calculateDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>, analysisMode: DevelopmentAnalysisMode) -> Float {
        if analysisMode == .tone {
            return euclideanDistance2D(a, b)
        } else {
            return euclideanDistance(a, b)
        }
    }
    
    /// 欧几里得距离（三维，L, a, b）
    private func euclideanDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diff = a - b
        return sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
    }
    
    /// 欧几里得距离（二维，只用 a, b）
    private func euclideanDistance2D(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diffA = a.y - b.y  // a 分量
        let diffB = a.z - b.z  // b 分量
        return sqrt(diffA * diffA + diffB * diffB)
    }
    
    // MARK: - Silhouette Score
    
    /// 计算整体轮廓系数
    /// - Parameters:
    ///   - points: 所有数据点（LAB空间）
    ///   - assignments: 每个点的簇分配
    ///   - centroids: 各簇的质心（LAB空间）
    ///   - analysisMode: 显影解析模式（色调模式只用 a, b，综合模式用 L, a, b）
    /// - Returns: Silhouette Score，范围 [-1, 1]，越接近1越好
    func calculateSilhouetteScore(
        points: [SIMD3<Float>],
        assignments: [Int],
        centroids: [SIMD3<Float>],
        analysisMode: DevelopmentAnalysisMode = .comprehensive
    ) -> Double {
        guard points.count > 0 && points.count == assignments.count else {
            return 0.0
        }
        
        let k = centroids.count
        guard k >= 2 else {
            return 0.0  // 只有1个簇时无法计算
        }
        
        let modeDesc = analysisMode == .tone ? "色调模式" : "综合模式"
        print("🔍 计算 Silhouette Score (K=\(k), N=\(points.count), \(modeDesc))...")
        
        var totalScore = 0.0
        var validSamples = 0
        
        // 为每个点计算轮廓系数
        for i in 0..<points.count {
            let point = points[i]
            let clusterIndex = assignments[i]
            
            // a(i): 点到同簇其他点的平均距离
            let a = averageDistanceToCluster(
                point: point,
                pointIndex: i,
                clusterIndex: clusterIndex,
                points: points,
                assignments: assignments,
                analysisMode: analysisMode
            )
            
            // b(i): 点到最近邻簇的平均距离
            let b = minimumAverageDistanceToOtherClusters(
                point: point,
                currentCluster: clusterIndex,
                k: k,
                points: points,
                assignments: assignments,
                analysisMode: analysisMode
            )
            
            // s(i) = (b - a) / max(a, b)
            if a > 0 || b > 0 {
                let maxDist = max(a, b)
                let silhouette = maxDist > 0 ? (b - a) / maxDist : 0.0
                totalScore += silhouette
                validSamples += 1
            }
        }
        
        let score = validSamples > 0 ? totalScore / Double(validSamples) : 0.0
        print("   → Silhouette Score: \(String(format: "%.4f", score))")
        return score
    }
    
    // MARK: - Private Methods
    
    /// 计算点到同簇其他点的平均距离
    private func averageDistanceToCluster(
        point: SIMD3<Float>,
        pointIndex: Int,
        clusterIndex: Int,
        points: [SIMD3<Float>],
        assignments: [Int],
        analysisMode: DevelopmentAnalysisMode
    ) -> Double {
        var totalDistance = 0.0
        var count = 0
        
        for i in 0..<points.count {
            if i != pointIndex && assignments[i] == clusterIndex {
                let distance = calculateDistance(point, points[i], analysisMode: analysisMode)
                totalDistance += Double(distance)
                count += 1
            }
        }
        
        return count > 0 ? totalDistance / Double(count) : 0.0
    }
    
    /// 计算点到其他簇的最小平均距离
    private func minimumAverageDistanceToOtherClusters(
        point: SIMD3<Float>,
        currentCluster: Int,
        k: Int,
        points: [SIMD3<Float>],
        assignments: [Int],
        analysisMode: DevelopmentAnalysisMode
    ) -> Double {
        var minAvgDistance = Double.greatestFiniteMagnitude
        
        for clusterIndex in 0..<k {
            if clusterIndex == currentCluster {
                continue
            }
            
            var totalDistance = 0.0
            var count = 0
            
            for i in 0..<points.count {
                if assignments[i] == clusterIndex {
                    let distance = calculateDistance(point, points[i], analysisMode: analysisMode)
                    totalDistance += Double(distance)
                    count += 1
                }
            }
            
            if count > 0 {
                let avgDistance = totalDistance / Double(count)
                minAvgDistance = min(minAvgDistance, avgDistance)
            }
        }
        
        return minAvgDistance == Double.greatestFiniteMagnitude ? 0.0 : minAvgDistance
    }
    
    // MARK: - K Selection Helper
    
    /// 选择最优的K值
    /// - Parameter scores: K值对应的Silhouette Score字典
    /// - Returns: 最优K值
    func selectOptimalK(from scores: [Int: Double]) -> Int {
        guard !scores.isEmpty else { return 5 }
        
        // 找到得分最高的K
        let sorted = scores.sorted { $0.value > $1.value }
        let optimalK = sorted.first?.key ?? 5
        
        print("📊 各K值的Silhouette Score:")
        for (k, score) in sorted {
            let indicator = k == optimalK ? "⭐️" : "  "
            print("\(indicator) K=\(k): \(String(format: "%.4f", score))")
        }
        
        return optimalK
    }
    
    // MARK: - Davies-Bouldin Index (备选指标)
    
    /// 计算Davies-Bouldin指数（值越小越好）
    func calculateDaviesBouldinIndex(
        points: [SIMD3<Float>],
        assignments: [Int],
        centroids: [SIMD3<Float>]
    ) -> Double {
        let k = centroids.count
        guard k >= 2 else { return 0.0 }
        
        // 计算每个簇的平均半径
        var clusterRadii = [Double](repeating: 0.0, count: k)
        var clusterCounts = [Int](repeating: 0, count: k)
        
        for i in 0..<points.count {
            let clusterIndex = assignments[i]
            let distance = euclideanDistance(points[i], centroids[clusterIndex])
            clusterRadii[clusterIndex] += Double(distance)
            clusterCounts[clusterIndex] += 1
        }
        
        for i in 0..<k {
            if clusterCounts[i] > 0 {
                clusterRadii[i] /= Double(clusterCounts[i])
            }
        }
        
        // 计算DB指数
        var dbSum = 0.0
        for i in 0..<k {
            var maxRatio = 0.0
            for j in 0..<k {
                if i != j {
                    let centroidDistance = Double(euclideanDistance(centroids[i], centroids[j]))
                    if centroidDistance > 0 {
                        let ratio = (clusterRadii[i] + clusterRadii[j]) / centroidDistance
                        maxRatio = max(maxRatio, ratio)
                    }
                }
            }
            dbSum += maxRatio
        }
        
        return dbSum / Double(k)
    }
}

// MARK: - Quality Level Helper

extension ClusterQualityEvaluator {
    
    /// 评估聚类质量等级
    enum QualityLevel: String {
        case excellent = "优秀"
        case good = "良好"
        case fair = "一般"
        case poor = "较差"
        
        static func from(silhouetteScore: Double) -> QualityLevel {
            if silhouetteScore >= 0.7 {
                return .excellent
            } else if silhouetteScore >= 0.5 {
                return .good
            } else if silhouetteScore >= 0.25 {
                return .fair
            } else {
                return .poor
            }
        }
        
        var emoji: String {
            switch self {
            case .excellent: return "🌟"
            case .good: return "✅"
            case .fair: return "⚠️"
            case .poor: return "❌"
            }
        }
    }
    
    func evaluateQuality(silhouetteScore: Double) -> (level: QualityLevel, description: String) {
        let level = QualityLevel.from(silhouetteScore: silhouetteScore)
        
        let description: String
        switch level {
        case .excellent:
            description = "聚类结构非常清晰，色系区分明显"
        case .good:
            description = "聚类结构较好，色系区分合理"
        case .fair:
            description = "聚类结构一般，存在一定重叠"
        case .poor:
            description = "聚类结构不佳，色系区分不明显"
        }
        
        return (level, description)
    }
}

