//
//  SimpleKMeans.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 1: 固定K=5的KMeans聚类（RGB空间）
//  Updated in Phase 2: 支持 LAB 空间和 ΔE 距离
//

import Foundation

enum ColorSpace {
    case rgb
    case lab
}

class SimpleKMeans {
    
    private let converter = ColorSpaceConverter()
    private var colorSpace: ColorSpace = .rgb
    
    // MARK: - 聚类结果
    struct ClusteringResult {
        var centroids: [SIMD3<Float>]  // 质心
        var assignments: [Int]  // 每个点的簇分配
        var clusterSizes: [Int]  // 每个簇的大小
    }
    
    // MARK: - 执行聚类
    func cluster(points: [SIMD3<Float>], k: Int = 5, maxIterations: Int = 50, colorSpace: ColorSpace = .rgb) -> ClusteringResult? {
        self.colorSpace = colorSpace
        
        guard points.count >= k else {
            print("Warning: Not enough points (\(points.count)) for k=\(k)")
            return nil
        }
        
        print("🎨 KMeans clustering in \(colorSpace) space with K=\(k)")
        
        // 1. 使用k-means++初始化质心
        var centroids = initializeCentroidsKMeansPlusPlus(points: points, k: k)
        
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
            
            // 2b. 重新计算质心
            var newCentroids = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: k)
            var counts = [Int](repeating: 0, count: k)
            
            for (pointIndex, point) in points.enumerated() {
                let cluster = assignments[pointIndex]
                newCentroids[cluster] += point
                counts[cluster] += 1
            }
            
            for i in 0..<k {
                if counts[i] > 0 {
                    centroids[i] = newCentroids[i] / Float(counts[i])
                } else {
                    // 如果某个簇为空，随机重新初始化
                    centroids[i] = points.randomElement() ?? SIMD3<Float>(0.5, 0.5, 0.5)
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
    
    // MARK: - 距离计算（根据颜色空间选择）
    private func calculateDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        switch colorSpace {
        case .rgb:
            return euclideanDistance(a, b)
        case .lab:
            return converter.deltaE(a, b)
        }
    }
    
    // MARK: - 欧氏距离
    private func euclideanDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diff = a - b
        return sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
    }
}

