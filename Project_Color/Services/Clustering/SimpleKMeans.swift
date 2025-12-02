//
//  SimpleKMeans.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 1: 固定K=5的KMeans聚类（RGB空间）
//  Updated in Phase 2: 支持 LAB 空间和 ΔE 距离
//  Updated: 支持色调模式（只用 a, b 聚类）和综合模式（L, a, b 聚类）
//

import Foundation

enum ColorSpace {
    case rgb
    case lab
}

/// 显影解析模式
enum DevelopmentAnalysisMode {
    case tone           // 色调模式：只用 a, b 进行聚类，L 固定为 50
    case comprehensive  // 综合模式：使用完整的 L, a, b 进行聚类
}

class SimpleKMeans {
    
    private let converter = ColorSpaceConverter()
    private var colorSpace: ColorSpace = .rgb
    private var analysisMode: DevelopmentAnalysisMode = .comprehensive
    
    /// 色调模式下 L 的固定值
    private let toneModeLValue: Float = 50.0
    
    // MARK: - 聚类结果
    struct ClusteringResult {
        var centroids: [SIMD3<Float>]  // 质心
        var assignments: [Int]  // 每个点的簇分配
        var clusterSizes: [Int]  // 每个簇的大小
    }
    
    // MARK: - 执行聚类
    func cluster(
        points: [SIMD3<Float>],
        k: Int = 5,
        maxIterations: Int = 50,
        colorSpace: ColorSpace = .rgb,
        weights: [Float]? = nil,  // 可选权重
        analysisMode: DevelopmentAnalysisMode = .comprehensive  // 显影解析模式
    ) -> ClusteringResult? {
        self.colorSpace = colorSpace
        self.analysisMode = analysisMode
        
        guard points.count >= k else {
            print("Warning: Not enough points (\(points.count)) for k=\(k)")
            return nil
        }
        
        let modeDesc = analysisMode == .tone ? "色调模式(a,b)" : "综合模式(L,a,b)"
        print("🎨 KMeans clustering in \(colorSpace) space with K=\(k), \(modeDesc)")
        
        // 1. 使用k-means++初始化质心
        var centroids = initializeCentroidsKMeansPlusPlus(points: points, k: k)
        
        // 色调模式：将质心的 L 值固定为 50
        if analysisMode == .tone && colorSpace == .lab {
            centroids = centroids.map { SIMD3<Float>(toneModeLValue, $0.y, $0.z) }
        }
        
        var assignments = [Int](repeating: 0, count: points.count)
        var hasConverged = false
        
        // 2. 迭代优化
        for iteration in 0..<maxIterations {
            let oldAssignments = assignments
            
            // 2a. 分配点到最近的质心
            for (pointIndex, point) in points.enumerated() {
                var minDistance = Float.greatestFiniteMagnitude
                var closestCentroid = 0
                
                for (centroidIndex, centroid) in centroids.enumerated() {
                    let distance = calculateDistance(point, centroid)
                    if distance < minDistance {
                        minDistance = distance
                        closestCentroid = centroidIndex
                    }
                }
                
                assignments[pointIndex] = closestCentroid
            }
            
            // 2b. 重新计算质心（支持权重）
            if let weights = weights {
                // 带权重的质心计算
                var newCentroids = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: k)
                var totalWeights = [Float](repeating: 0, count: k)
                
                for (pointIndex, point) in points.enumerated() {
                    let cluster = assignments[pointIndex]
                    let weight = weights[pointIndex]
                    newCentroids[cluster] += point * weight
                    totalWeights[cluster] += weight
                }
                
                for i in 0..<k {
                    if totalWeights[i] > 0 {
                        var newCentroid = newCentroids[i] / totalWeights[i]
                        // 色调模式：L 值固定为 50
                        if analysisMode == .tone && colorSpace == .lab {
                            newCentroid.x = toneModeLValue
                        }
                        centroids[i] = newCentroid
                    } else {
                        // 如果某个簇为空，随机重新初始化
                        var fallback = points.randomElement() ?? SIMD3<Float>(0.5, 0.5, 0.5)
                        if analysisMode == .tone && colorSpace == .lab {
                            fallback.x = toneModeLValue
                        }
                        centroids[i] = fallback
                    }
                }
            } else {
                // 无权重的质心计算（原有逻辑）
                var newCentroids = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: k)
                var counts = [Int](repeating: 0, count: k)
                
                for (pointIndex, point) in points.enumerated() {
                    let cluster = assignments[pointIndex]
                    newCentroids[cluster] += point
                    counts[cluster] += 1
                }
                
                for i in 0..<k {
                    if counts[i] > 0 {
                        var newCentroid = newCentroids[i] / Float(counts[i])
                        // 色调模式：L 值固定为 50
                        if analysisMode == .tone && colorSpace == .lab {
                            newCentroid.x = toneModeLValue
                        }
                        centroids[i] = newCentroid
                    } else {
                        // 如果某个簇为空，随机重新初始化
                        var fallback = points.randomElement() ?? SIMD3<Float>(0.5, 0.5, 0.5)
                        if analysisMode == .tone && colorSpace == .lab {
                            fallback.x = toneModeLValue
                        }
                        centroids[i] = fallback
                    }
                }
            }
            
            // 2c. 检查收敛
            if assignments == oldAssignments {
                hasConverged = true
                print("KMeans converged at iteration \(iteration)")
                break
            }
        }
        
        if !hasConverged {
            print("KMeans reached max iterations without full convergence")
        }
        
        // 3. 计算簇大小
        var clusterSizes = [Int](repeating: 0, count: k)
        for assignment in assignments {
            clusterSizes[assignment] += 1
        }
        
        return ClusteringResult(
            centroids: centroids,
            assignments: assignments,
            clusterSizes: clusterSizes
        )
    }
    
    // MARK: - k-means++ 初始化
    private func initializeCentroidsKMeansPlusPlus(points: [SIMD3<Float>], k: Int) -> [SIMD3<Float>] {
        var centroids: [SIMD3<Float>] = []
        
        // 1. 随机选择第一个质心
        if let firstCentroid = points.randomElement() {
            centroids.append(firstCentroid)
        }
        
        // 2. 选择剩余的k-1个质心
        for _ in 1..<k {
            var distances = [Float](repeating: 0, count: points.count)
            var totalDistance: Float = 0
            
            // 计算每个点到最近质心的距离
            for (pointIndex, point) in points.enumerated() {
                var minDistance = Float.greatestFiniteMagnitude
                
                for centroid in centroids {
                    let distance = calculateDistance(point, centroid)
                    minDistance = min(minDistance, distance)
                }
                
                distances[pointIndex] = minDistance * minDistance  // 使用平方距离
                totalDistance += distances[pointIndex]
            }
            
            // 使用轮盘赌选择下一个质心
            if totalDistance > 0 {
                let randomValue = Float.random(in: 0..<totalDistance)
                var cumulativeDistance: Float = 0
                
                for (pointIndex, distance) in distances.enumerated() {
                    cumulativeDistance += distance
                    if cumulativeDistance >= randomValue {
                        centroids.append(points[pointIndex])
                        break
                    }
                }
            } else {
                // 如果所有距离为0，随机选择
                if let randomPoint = points.randomElement() {
                    centroids.append(randomPoint)
                }
            }
        }
        
        return centroids
    }
    
    // MARK: - 距离计算
    /// 根据模式计算距离：
    /// - 综合模式：使用完整的 L, a, b 三维欧几里得距离
    /// - 色调模式：只使用 a, b 二维欧几里得距离
    private func calculateDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        if analysisMode == .tone && colorSpace == .lab {
            // 色调模式：只计算 a, b 的距离
            return euclideanDistance2D(a, b)
        } else {
            // 综合模式：计算完整的 L, a, b 距离
            return euclideanDistance(a, b)
        }
    }
    
    // MARK: - 欧氏距离（三维）
    private func euclideanDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diff = a - b
        return sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
    }
    
    // MARK: - 欧氏距离（二维，只用 a, b）
    /// 色调模式专用：只计算 Lab 空间中 a, b 分量的距离
    private func euclideanDistance2D(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diffA = a.y - b.y  // a 分量
        let diffB = a.z - b.z  // b 分量
        return sqrt(diffA * diffA + diffB * diffB)
    }
}

