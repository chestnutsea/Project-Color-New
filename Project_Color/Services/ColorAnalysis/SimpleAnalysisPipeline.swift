//
//  SimpleAnalysisPipeline.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 1: 简化分析管线（串行处理）
//  Micro-Phase 5 Stage B: 并发处理管线
//

import Foundation
import Photos
#if canImport(UIKit)
import UIKit
#endif

class SimpleAnalysisPipeline {
    
    private let colorExtractor = SimpleColorExtractor()
    private let colorNamer = ColorNameResolver()  // Phase 2: 使用 CSS 颜色命名
    private let kmeans = SimpleKMeans()
    private let converter = ColorSpaceConverter()  // Phase 2: LAB 转换
    private let coreDataManager = CoreDataManager.shared  // Phase 3: 持久化
    private let autoKSelector = AutoKSelector()  // Phase 4: 自动选K
    private let adaptiveManager = AdaptiveClusterManager()  // Phase 5: 自适应聚类
    private let colorCache = PhotoColorCache()  // Phase 5: 缓存管理
    private let settings = AnalysisSettings.shared  // Phase 5: 用户设置
    
    // Phase 5: 并发控制
    private let maxConcurrentExtractions = 8  // 最多同时处理8张照片
    
    // Phase 5: 是否启用自适应更新
    var enableAdaptiveClustering = true
    
    // Phase 5: 是否启用缓存
    var enableCaching = true
    
    // MARK: - Progress Tracker Actor
    
    /// Actor for thread-safe progress tracking
    private actor ProgressTracker {
        var processedCount: Int
        var failedCount = 0
        
        init(initialCount: Int) {
            self.processedCount = initialCount
        }
        
        func incrementProcessed() {
            processedCount += 1
        }
        
        func incrementFailed() {
            failedCount += 1
        }
        
        func getCounts() -> (processed: Int, failed: Int) {
            return (processedCount, failedCount)
        }
    }
    
    // MARK: - 主分析方法
    func analyzePhotos(
        assets: [PHAsset],
        progressHandler: @escaping (AnalysisProgress) -> Void
    ) async -> AnalysisResult {
        
        let result = AnalysisResult()
        result.totalPhotoCount = assets.count
        result.timestamp = Date()
        
        var allMainColorsLAB: [SIMD3<Float>] = []  // Phase 2: 收集所有主色点（LAB空间）
        var photoInfos: [PhotoColorInfo] = []
        
        // 用于计算预计时间
        let startTime = Date()
        
        // Phase 5: 缓存检查
        var assetsToProcess: [PHAsset] = assets
        var cachedInfos: [PhotoColorInfo] = []
        
        if enableCaching {
            let (uncached, cached) = colorCache.filterUncached(assets: assets)
            assetsToProcess = uncached
            cachedInfos = cached
            
            // 缓存的结果直接添加到两个地方
            photoInfos.append(contentsOf: cachedInfos)
            
            await MainActor.run {
                result.photoInfos.append(contentsOf: cachedInfos)
                result.processedCount = cachedInfos.count
            }
        }
        
        // Phase 5: 并发提取照片主色
        // 使用 actor 保护共享状态
        let progressTracker = ProgressTracker(initialCount: cachedInfos.count)
        
        // 阶段1: 并发提取每张照片的主色（仅处理未缓存的）
        await withTaskGroup(of: (Int, PhotoColorInfo?).self) { group in
            // 为每张未缓存的照片创建一个任务
            for (index, asset) in assetsToProcess.enumerated() {
                group.addTask {
                    let photoInfo = await self.extractPhotoColors(asset: asset)
                    return (index, photoInfo)
                }
                
                // 限制并发数量
                if (index + 1) % maxConcurrentExtractions == 0 {
                    // 等待一批完成
                    if let (resultIndex, photoInfo) = await group.next() {
                        await self.processPhotoResult(
                            index: resultIndex,
                            photoInfo: photoInfo,
                            progressTracker: progressTracker,
                            result: result,
                            startTime: startTime,
                            totalPhotos: assets.count,
                            cachedCount: cachedInfos.count,
                            progressHandler: progressHandler
                        )
                    }
                }
            }
            
            // 收集剩余的所有结果
            var results: [(Int, PhotoColorInfo?)] = []
            for await taskResult in group {
                results.append(taskResult)
            }
            
            // 按索引排序以保持顺序
            results.sort { $0.0 < $1.0 }
            
            // 处理所有结果
            for (index, photoInfo) in results {
                await self.processPhotoResult(
                    index: index,
                    photoInfo: photoInfo,
                    progressTracker: progressTracker,
                    result: result,
                    startTime: startTime,
                    totalPhotos: assets.count,
                    cachedCount: cachedInfos.count,
                    progressHandler: progressHandler
                )
            }
        }
        
        // 从所有照片（包括缓存）中收集主色用于聚类
        // 先从缓存的照片收集
        for photoInfo in cachedInfos {
            // 收集所有5个主色
            for color in photoInfo.dominantColors {
                let lab = converter.rgbToLab(color.rgb)
                allMainColorsLAB.append(lab)
            }
        }
        
        // 再从新提取的照片收集
        for photoInfo in result.photoInfos where !cachedInfos.contains(where: { $0.assetIdentifier == photoInfo.assetIdentifier }) {
            // 收集所有5个主色
            for color in photoInfo.dominantColors {
                let lab = converter.rgbToLab(color.rgb)
                allMainColorsLAB.append(lab)
            }
        }
        
        // 阶段2: 全局聚类（Phase 5: 并发自动选择最优K）
        await MainActor.run {
            // 计算K值选择的预计时间（约6-8秒）
            let elapsed = Date().timeIntervalSince(startTime)
            let kSelectionTime: TimeInterval = 7.0  // K值选择预计7秒
            let remainingTime = kSelectionTime + 3.0  // +3秒用于后续处理
            
            var progress = AnalysisProgress(
                currentPhoto: assets.count,
                totalPhotos: assets.count,
                currentStage: "自动选择最优色系数",
                overallProgress: 0.7,
                failedCount: result.failedCount,
                isSelectingK: true,
                cachedCount: cachedInfos.count,
                isConcurrent: true
            )
            progress.estimatedTimeRemaining = remainingTime
            progress.startTime = startTime
            progressHandler(progress)
        }
        
        // Phase 5: 使用并发K值选择
        // 计算合理的K值范围
        let minK = 3
        let maxK = max(minK, min(12, allMainColorsLAB.count / 10))  // 确保 maxK >= minK
        
        guard let kResult = await autoKSelector.findOptimalKConcurrent(
            points: allMainColorsLAB,
            config: AutoKSelector.Config(
                minK: minK,
                maxK: maxK,
                maxIterations: 50,
                colorSpace: .lab
            ),
            progressHandler: { currentK, totalK in
                Task { @MainActor in
                    progressHandler(AnalysisProgress(
                        currentPhoto: assets.count,
                        totalPhotos: assets.count,
                        currentStage: "自动选择最优色系数（并发）",
                        overallProgress: 0.7 + 0.1 * Double(currentK) / Double(totalK),
                        failedCount: result.failedCount,
                        currentK: currentK,
                        totalK: totalK,
                        isSelectingK: true
                    ))
                }
            }
        ) else {
            print("❌ 自动K选择失败，使用默认K=5")
            result.optimalK = 5
            result.qualityLevel = "未知"
            return result
        }
        
        // 保存质量指标
        result.optimalK = kResult.optimalK
        result.silhouetteScore = kResult.silhouetteScore
        result.qualityLevel = kResult.qualityLevel.rawValue
        result.qualityDescription = kResult.qualityDescription
        result.allKScores = kResult.allScores
        
        await MainActor.run {
            progressHandler(AnalysisProgress(
                currentPhoto: assets.count,
                totalPhotos: assets.count,
                currentStage: "颜色聚类中",
                overallProgress: 0.8,
                failedCount: result.failedCount
            ))
        }
        
        // 使用最优聚类结果
        let clusteringResult = kResult.bestClustering
        if true {
            // 创建簇对象
            var clusters: [ColorCluster] = []
            let centroidsLAB = clusteringResult.centroids  // 保存 LAB 质心用于距离计算
            
            for (index, centroidLAB) in centroidsLAB.enumerated() {
                // 将 LAB 质心转换回 RGB 用于显示
                let centroidRGB = converter.labToRgb(centroidLAB)
                
                // Phase 2: 使用 LAB 空间进行精确命名
                let colorName = colorNamer.getColorName(lab: centroidLAB)
                
                // 🔍 调试输出
                print("📊 Cluster \(index):")
                print("   LAB: L=\(centroidLAB.x), a=\(centroidLAB.y), b=\(centroidLAB.z)")
                print("   RGB: R=\(centroidRGB.x), G=\(centroidRGB.y), B=\(centroidRGB.z)")
                print("   Name: \(colorName)")
                
                clusters.append(ColorCluster(
                    index: index,
                    centroid: centroidRGB,  // 存储 RGB 用于显示
                    colorName: colorName
                ))
            }
            
            // 阶段3: 为每张照片分配主簇
            await MainActor.run {
                progressHandler(AnalysisProgress(
                    currentPhoto: assets.count,
                    totalPhotos: assets.count,
                    currentStage: "计算结果中",
                    overallProgress: 0.9,
                    failedCount: result.failedCount
                ))
            }
            
            // Phase 2: 使用 LAB 质心进行分配
            for i in 0..<photoInfos.count {
                assignPhotoToCluster(
                    photoInfo: &photoInfos[i],
                    clusters: clusters,
                    centroidsLAB: centroidsLAB
                )
            }
            
            // 统计每个簇的照片数（使用原始索引）
            for i in 0..<clusters.count {
                let photosInCluster = photoInfos.filter { $0.primaryClusterIndex == i }
                clusters[i].photoCount = photosInCluster.count
                clusters[i].photoIdentifiers = photosInCluster.map { $0.assetIdentifier }
            }
            
            // Phase 5: 按照片数量降序排列簇
            // 保存旧索引到新索引的映射
            var oldToNewIndex: [Int: Int] = [:]
            let sortedClusters = clusters.sorted { $0.photoCount > $1.photoCount }
            for (newIndex, cluster) in sortedClusters.enumerated() {
                oldToNewIndex[cluster.index] = newIndex
            }
            
            // 更新照片的簇索引
            for i in 0..<photoInfos.count {
                if let oldIndex = photoInfos[i].primaryClusterIndex,
                   let newIndex = oldToNewIndex[oldIndex] {
                    photoInfos[i].primaryClusterIndex = newIndex
                }
            }
            
            // 应用排序并重新分配索引
            clusters = sortedClusters
            for i in 0..<clusters.count {
                clusters[i].index = i
                // 重新统计照片（使用新索引）
                let photosInCluster = photoInfos.filter { $0.primaryClusterIndex == i }
                clusters[i].photoCount = photosInCluster.count
                clusters[i].photoIdentifiers = photosInCluster.map { $0.assetIdentifier }
            }
            
            // Phase 5: 自适应聚类更新
            if enableAdaptiveClustering {
                await MainActor.run {
                    progressHandler(AnalysisProgress(
                        currentPhoto: assets.count,
                        totalPhotos: assets.count,
                        currentStage: "优化聚类结果",
                        overallProgress: 0.95,
                        failedCount: result.failedCount,
                        cachedCount: cachedInfos.count,
                        isConcurrent: false
                    ))
                }
                
                // Phase 5: 使用用户设置或默认配置
                let adaptiveConfig = AdaptiveClusterManager.Config(
                    mergeThresholdDeltaE: settings.effectiveMergeThreshold,
                    minClusterSize: settings.effectiveMinClusterSize,
                    splitThresholdIntraDist: 40.0,
                    useColorNameSimilarity: settings.effectiveUseColorNameSimilarity
                )
                
                print("📊 自适应聚类配置:")
                print("   - 合并阈值 ΔE: \(String(format: "%.1f", adaptiveConfig.mergeThresholdDeltaE))")
                print("   - 最小簇大小: \(adaptiveConfig.minClusterSize)")
                print("   - 名称相似性: \(adaptiveConfig.useColorNameSimilarity ? "开启" : "关闭")")
                
                let (updatedClusters, updateResult) = adaptiveManager.updateClusters(
                    clusters: clusters,
                    photoInfos: photoInfos,
                    allColorsLAB: allMainColorsLAB,
                    config: adaptiveConfig
                )
                
                result.clusters = updatedClusters
                
                // 更新进度以显示自适应操作
                await MainActor.run {
                    var finalProgress = AnalysisProgress(
                        currentPhoto: assets.count,
                        totalPhotos: assets.count,
                        currentStage: "优化聚类结果",
                        overallProgress: 0.98,
                        failedCount: result.failedCount,
                        cachedCount: cachedInfos.count,
                        adaptiveOperations: updateResult.operations
                    )
                    progressHandler(finalProgress)
                }
                
                // 保存更新操作日志
                print("📋 自适应更新操作:")
                for operation in updateResult.operations {
                    print("   \(operation)")
                }
            } else {
                result.clusters = clusters
            }
        }
        
        result.photoInfos = photoInfos
        result.isCompleted = true
        
        // 完成
        await MainActor.run {
            progressHandler(AnalysisProgress(
                currentPhoto: assets.count,
                totalPhotos: assets.count,
                currentStage: "分析完成",
                overallProgress: 1.0,
                failedCount: result.failedCount
            ))
        }
        
        // Phase 3: 保存到 Core Data (后台线程)
        Task.detached(priority: .background) {
            do {
                print("📝 开始保存分析结果到Core Data...")
                print("   - clusters: \(result.clusters.count)")
                print("   - photoInfos: \(result.photoInfos.count)")
                
                let savedSession = try self.coreDataManager.saveAnalysisSession(from: result)
                await MainActor.run {
                    print("✅ 分析结果已保存到Core Data (Session ID: \(savedSession.id ?? UUID()))")
                }
            } catch {
                await MainActor.run {
                    print("⚠️ 保存分析结果失败: \(error)")
                    print("   错误详情: \(error.localizedDescription)")
                }
            }
        }
        
        return result
    }
    
    // MARK: - 提取单张照片的主色
    private func extractPhotoColors(asset: PHAsset) async -> PhotoColorInfo? {
        #if canImport(UIKit)
        return await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            
            let targetSize = CGSize(width: 300, height: 300)
            
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { [weak self] image, info in
                guard let self = self,
                      let image = image,
                      let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // 提取主色
                let dominantColors = self.colorExtractor.extractDominantColors(from: cgImage, count: 5)
                
                // 命名主色
                var namedColors = dominantColors
                for i in 0..<namedColors.count {
                    namedColors[i].colorName = self.colorNamer.getColorName(rgb: namedColors[i].rgb)
                }
                
                let photoInfo = PhotoColorInfo(
                    assetIdentifier: asset.localIdentifier,
                    dominantColors: namedColors
                )
                
                continuation.resume(returning: photoInfo)
            }
        }
        #else
        return nil
        #endif
    }
    
    // MARK: - 为照片分配主簇（Phase 2: 使用 LAB 空间）
    private func assignPhotoToCluster(
        photoInfo: inout PhotoColorInfo,
        clusters: [ColorCluster],
        centroidsLAB: [SIMD3<Float>]
    ) {
        // 计算每个主色到各个簇的距离（LAB 空间）
        var clusterScores = [Int: Double]()
        
        for dominantColor in photoInfo.dominantColors {
            // 转换为 LAB
            let colorLAB = converter.rgbToLab(dominantColor.rgb)
            
            var minDistance = Float.greatestFiniteMagnitude
            var closestCluster = 0
            
            // Phase 2: 使用 ΔE 距离
            for (index, centroidLAB) in centroidsLAB.enumerated() {
                let distance = converter.deltaE(colorLAB, centroidLAB)
                if distance < minDistance {
                    minDistance = distance
                    closestCluster = index
                }
            }
            
            // 累计该簇的权重
            clusterScores[closestCluster, default: 0] += Double(dominantColor.weight)
        }
        
        // 找到权重最大的簇作为主簇
        if let primaryCluster = clusterScores.max(by: { $0.value < $1.value }) {
            photoInfo.primaryClusterIndex = primaryCluster.key
            photoInfo.clusterMix = clusterScores
        }
    }
    
    // MARK: - Phase 5: 处理单张照片的提取结果（并发辅助）
    private func processPhotoResult(
        index: Int,
        photoInfo: PhotoColorInfo?,
        progressTracker: any Actor,
        result: AnalysisResult,
        startTime: Date,
        totalPhotos: Int,
        cachedCount: Int,
        progressHandler: @escaping (AnalysisProgress) -> Void
    ) async {
        // Cast progressTracker to the correct type
        guard let tracker = progressTracker as? ProgressTracker else { return }
        
        if let photoInfo = photoInfo {
            await MainActor.run {
                result.photoInfos.append(photoInfo)
                result.processedCount += 1
            }
            await tracker.incrementProcessed()
        } else {
            await MainActor.run {
                result.failedCount += 1
            }
            await tracker.incrementFailed()
        }
        
        // 更新进度
        let counts = await tracker.getCounts()
        let currentCount = counts.processed + counts.failed
        
        // 计算预计剩余时间
        let elapsed: TimeInterval = Date().timeIntervalSince(startTime)
        let avgTimePerPhoto = currentCount > 0 ? elapsed / Double(currentCount) : 0.0
        let remainingPhotos = Double(totalPhotos - currentCount)
        let estimatedRemaining: TimeInterval = avgTimePerPhoto * remainingPhotos + 10.0  // +10秒用于聚类
        
        await MainActor.run {
            var progress = AnalysisProgress(
                currentPhoto: currentCount,
                totalPhotos: totalPhotos,
                currentStage: "颜色提取中",
                overallProgress: Double(currentCount) / Double(totalPhotos) * 0.7,
                failedCount: counts.failed,
                cachedCount: cachedCount,
                isConcurrent: true
            )
            progress.estimatedTimeRemaining = estimatedRemaining
            progress.startTime = startTime
            progressHandler(progress)
        }
    }
}

