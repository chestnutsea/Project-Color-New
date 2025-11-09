//
//  AutoKSelector.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 4: 自动选择最优K值
//  Micro-Phase 5 Stage B: 并发K值测试
//

import Foundation

/// 自动K值选择器
class AutoKSelector {
    
    private let kmeans = SimpleKMeans()
    private let evaluator = ClusterQualityEvaluator()
    
    // Phase 5: 并发控制（限制并发聚类数量）
    private let maxConcurrentKTests = 4
    
    // MARK: - Configuration
    
    struct Config {
        let minK: Int
        let maxK: Int
        let maxIterations: Int
        let colorSpace: ColorSpace
        
        static let `default` = Config(
            minK: 3,
            maxK: 12,
            maxIterations: 50,
            colorSpace: .lab
        )
    }
    
    // MARK: - Result
    
    struct Result {
        let optimalK: Int
        let silhouetteScore: Double
        let allScores: [Int: Double]
        let bestClustering: SimpleKMeans.ClusteringResult
        let qualityLevel: ClusterQualityEvaluator.QualityLevel
        let qualityDescription: String
    }
    
    // MARK: - Find Optimal K
    
    /// 自动选择最优K值
    /// - Parameters:
    ///   - points: 数据点（LAB空间）
    ///   - config: 配置参数
    ///   - progressHandler: 进度回调 (currentK, totalK)
    /// - Returns: 选择结果
    func findOptimalK(
        points: [SIMD3<Float>],
        config: Config = .default,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) -> Result? {
        guard points.count >= config.maxK else {
            print("⚠️ 数据点数量不足，无法测试K=\(config.maxK)")
            return nil
        }
        
        print("🔍 开始自动选择最优K值...")
        print("   范围: K=\(config.minK) 到 K=\(config.maxK)")
        print("   数据点: \(points.count) 个")
        
        var scores: [Int: Double] = [:]
        var clusterings: [Int: SimpleKMeans.ClusteringResult] = [:]
        
        let totalTests = config.maxK - config.minK + 1
        
        // 测试每个K值
        for k in config.minK...config.maxK {
            progressHandler?(k - config.minK + 1, totalTests)
            
            print("\n📊 测试 K=\(k)...")
            
            // 执行聚类
            guard let clustering = kmeans.cluster(
                points: points,
                k: k,
                maxIterations: config.maxIterations,
                colorSpace: config.colorSpace
            ) else {
                print("   ⚠️ K=\(k) 聚类失败")
                continue
            }
            
            // 计算Silhouette Score
            let score = evaluator.calculateSilhouetteScore(
                points: points,
                assignments: clustering.assignments,
                centroids: clustering.centroids
            )
            
            scores[k] = score
            clusterings[k] = clustering
            
            print("   K=\(k) → Silhouette: \(String(format: "%.4f", score))")
        }
        
        // 选择最优K
        let optimalK = evaluator.selectOptimalK(from: scores)
        
        guard let bestScore = scores[optimalK],
              let bestClustering = clusterings[optimalK] else {
            print("❌ 未能选择最优K值")
            return nil
        }
        
        let (level, description) = evaluator.evaluateQuality(silhouetteScore: bestScore)
        
        print("\n✅ 选择最优 K=\(optimalK)")
        print("   Silhouette Score: \(String(format: "%.4f", bestScore))")
        print("   质量等级: \(level.emoji) \(level.rawValue)")
        
        return Result(
            optimalK: optimalK,
            silhouetteScore: bestScore,
            allScores: scores,
            bestClustering: bestClustering,
            qualityLevel: level,
            qualityDescription: description
        )
    }
    
    // MARK: - Quick Selection (Fast)
    
    /// 快速选择（采样策略，适合大数据集）
    func findOptimalKFast(
        points: [SIMD3<Float>],
        sampleSize: Int = 1000,
        config: Config = .default,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) -> Result? {
        // 如果数据量小，直接使用完整算法
        guard points.count > sampleSize * 2 else {
            return findOptimalK(points: points, config: config, progressHandler: progressHandler)
        }
        
        print("🚀 使用快速模式（采样 \(sampleSize) 个点）")
        
        // 随机采样
        let sampledPoints = points.shuffled().prefix(sampleSize).map { $0 }
        
        // 在采样数据上选择K
        return findOptimalK(points: sampledPoints, config: config, progressHandler: progressHandler)
    }
    
    // MARK: - Phase 5: Concurrent K Selection
    
    /// 并发版本：自动选择最优K值（并行测试所有K）
    /// - Parameters:
    ///   - points: 数据点（LAB空间）
    ///   - config: 配置参数
    ///   - progressHandler: 进度回调 (currentK, totalK)
    /// - Returns: 选择结果
    func findOptimalKConcurrent(
        points: [SIMD3<Float>],
        config: Config = .default,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async -> Result? {
        guard points.count >= config.maxK else {
            print("⚠️ 数据点数量不足，无法测试K=\(config.maxK)")
            return nil
        }
        
        print("🔍 开始并发自动选择最优K值...")
        print("   范围: K=\(config.minK) 到 K=\(config.maxK)")
        print("   数据点: \(points.count) 个")
        print("   最大并发: \(maxConcurrentKTests)")
        
        let totalTests = config.maxK - config.minK + 1
        
        // 用 actor 保护共享状态
        actor ResultCollector {
            var scores: [Int: Double] = [:]
            var clusterings: [Int: SimpleKMeans.ClusteringResult] = [:]
            var completedCount = 0
            
            func add(k: Int, score: Double, clustering: SimpleKMeans.ClusteringResult) {
                scores[k] = score
                clusterings[k] = clustering
                completedCount += 1
            }
            
            func getResults() -> ([Int: Double], [Int: SimpleKMeans.ClusteringResult], Int) {
                return (scores, clusterings, completedCount)
            }
        }
        
        let collector = ResultCollector()
        
        // 并发测试所有K值
        await withTaskGroup(of: (Int, Double?, SimpleKMeans.ClusteringResult?).self) { group in
            var tasksAdded = 0
            
            for k in config.minK...config.maxK {
                // 限制并发数量
                if tasksAdded >= maxConcurrentKTests && tasksAdded < totalTests {
                    // 等待一个任务完成再添加新任务
                    if let (completedK, score, clustering) = await group.next() {
                        if let score = score, let clustering = clustering {
                            await collector.add(k: completedK, score: score, clustering: clustering)
                            
                            let (_, _, completedCount) = await collector.getResults()
                            progressHandler?(completedCount, totalTests)
                            
                            print("   K=\(completedK) → Silhouette: \(String(format: "%.4f", score))")
                        } else {
                            print("   ⚠️ K=\(completedK) 聚类失败")
                        }
                    }
                }
                
                // 创建一个新的 SimpleKMeans 实例用于并发（避免共享状态）
                group.addTask { [config] in
                    let localKMeans = SimpleKMeans()
                    let localEvaluator = ClusterQualityEvaluator()
                    
                    print("\n📊 测试 K=\(k)...")
                    
                    // 执行聚类
                    guard let clustering = localKMeans.cluster(
                        points: points,
                        k: k,
                        maxIterations: config.maxIterations,
                        colorSpace: config.colorSpace
                    ) else {
                        return (k, nil, nil)
                    }
                    
                    // 计算Silhouette Score
                    let score = localEvaluator.calculateSilhouetteScore(
                        points: points,
                        assignments: clustering.assignments,
                        centroids: clustering.centroids
                    )
                    
                    return (k, score, clustering)
                }
                
                tasksAdded += 1
            }
            
            // 收集所有剩余结果
            for await (completedK, score, clustering) in group {
                if let score = score, let clustering = clustering {
                    await collector.add(k: completedK, score: score, clustering: clustering)
                    
                    let (_, _, completedCount) = await collector.getResults()
                    progressHandler?(completedCount, totalTests)
                    
                    print("   K=\(completedK) → Silhouette: \(String(format: "%.4f", score))")
                } else {
                    print("   ⚠️ K=\(completedK) 聚类失败")
                }
            }
        }
        
        // 获取最终结果
        let (scores, clusterings, _) = await collector.getResults()
        
        // 选择最优K
        let optimalK = evaluator.selectOptimalK(from: scores)
        
        guard let bestScore = scores[optimalK],
              let bestClustering = clusterings[optimalK] else {
            print("❌ 未能选择最优K值")
            return nil
        }
        
        let (level, description) = evaluator.evaluateQuality(silhouetteScore: bestScore)
        
        print("\n✅ 选择最优 K=\(optimalK)")
        print("   Silhouette Score: \(String(format: "%.4f", bestScore))")
        print("   质量等级: \(level.emoji) \(level.rawValue)")
        
        return Result(
            optimalK: optimalK,
            silhouetteScore: bestScore,
            allScores: scores,
            bestClustering: bestClustering,
            qualityLevel: level,
            qualityDescription: description
        )
    }
}

// MARK: - Elbow Method (备选，作为参考)

extension AutoKSelector {
    
    /// 手肘法（计算簇内距离总和）
    func calculateInertia(
        points: [SIMD3<Float>],
        assignments: [Int],
        centroids: [SIMD3<Float>]
    ) -> Double {
        let converter = ColorSpaceConverter()
        var totalInertia = 0.0
        
        for i in 0..<points.count {
            let clusterIndex = assignments[i]
            let distance = converter.deltaE(points[i], centroids[clusterIndex])
            totalInertia += Double(distance * distance)
        }
        
        return totalInertia
    }
    
    /// 使用手肘法选择K（仅用于参考）
    func findElbow(points: [SIMD3<Float>], config: Config = .default) -> [Int: Double] {
        var inertias: [Int: Double] = [:]
        
        for k in config.minK...config.maxK {
            if let clustering = kmeans.cluster(points: points, k: k, colorSpace: config.colorSpace) {
                let inertia = calculateInertia(
                    points: points,
                    assignments: clustering.assignments,
                    centroids: clustering.centroids
                )
                inertias[k] = inertia
            }
        }
        
        return inertias
    }
}

