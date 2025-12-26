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
    private let colorNamer = ColorNameResolver.shared  // Phase 2: 使用 CSS 颜色命名（单例）
    private let kmeans = SimpleKMeans()
    private let converter = ColorSpaceConverter()  // Phase 2: LAB 转换
    private let coreDataManager = CoreDataManager.shared  // Phase 3: 持久化
    private let autoKSelector = AutoKSelector()  // Phase 4: 自动选K
    private let adaptiveManager = AdaptiveClusterManager()  // Phase 5: 自适应聚类
    private let colorCache = PhotoColorCache()  // Phase 5: 缓存管理
    private let settings = AnalysisSettings.shared  // Phase 5: 用户设置
    private let aiEvaluator = ColorAnalysisEvaluator()  // AI 评价
    private let warmCoolCalculator = WarmCoolScoreCalculator()  // 冷暖评分
    private let imageStatisticsCalculator = ImageStatisticsCalculator()  // 图像统计
    private let collectionFeatureCalculator = CollectionFeatureCalculator()  // 作品集聚合
    private let visionAnalyzer = VisionAnalyzer()  // Vision 识别
    private let metadataReader = PhotoMetadataReader()  // 照片元数据读取
    
    // Phase 5: 并发控制
    private let maxConcurrentExtractions = 8  // 最多同时处理8张照片
    
    // Phase 5: 是否启用缓存
    var enableCaching = true 
    
    // 用于收集压缩图片的 Actor（线程安全）
    // 使用字典存储，确保图片顺序与 photoInfos 一致
    private actor CompressedImageCollector {
        var imagesByIdentifier: [String: UIImage] = [:]
        
        func append(_ image: UIImage, identifier: String) {
            imagesByIdentifier[identifier] = image
        }
        
        // 按照指定的 identifier 顺序返回图片
        func getAll(orderedBy identifiers: [String]) -> [UIImage] {
            return identifiers.compactMap { imagesByIdentifier[$0] }
        }
    }
    
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
        albumInfoMap: [String: (identifier: String, name: String)] = [:],
        userMessage: String? = nil,
        progressHandler: @escaping (AnalysisProgress) -> Void
    ) async -> AnalysisResult {
        
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        NSLog("🎨 开始颜色分析")
        NSLog("   照片数量: \(assets.count)")
        if let msg = userMessage, !msg.isEmpty {
            NSLog("   用户感受: \(msg)")
        }
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let result = AnalysisResult()
        result.totalPhotoCount = assets.count
        result.timestamp = Date()
        
        // 设置用户输入的感受
        if let msg = userMessage, !msg.isEmpty {
            result.userMessage = msg
        }
        
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
            
            // 检查缓存的照片数据完整性
            var cachedComplete: [PhotoColorInfo] = []
            var cachedNeedingUpdate: [(asset: PHAsset, info: PhotoColorInfo)] = []
            
            for info in cachedInfos {
                // 检查是否有完整的数据：主色、CDF、冷暖评分
                let hasAdvancedAnalysis = info.advancedColorAnalysis != nil
                let hasBrightnessCDF = info.brightnessCDF != nil && !(info.brightnessCDF?.isEmpty ?? true)
                
                if hasAdvancedAnalysis && hasBrightnessCDF {
                    // 数据完整，直接使用
                    cachedComplete.append(info)
                } else {
                    // 数据不完整，需要补充计算
                    if let asset = assets.first(where: { $0.localIdentifier == info.assetIdentifier }) {
                        cachedNeedingUpdate.append((asset, info))
                    }
                }
            }
            
            NSLog("📊 缓存数据完整性检查:")
            NSLog("   - 数据完整（复用）: \(cachedComplete.count)")
            NSLog("   - 需要补充计算: \(cachedNeedingUpdate.count)")
            
            // 为不完整的缓存照片补充计算
            if !cachedNeedingUpdate.isEmpty {
                for (asset, var info) in cachedNeedingUpdate {
                    if let updatedInfo = await updateWarmCoolScore(asset: asset, photoInfo: info) {
                        cachedComplete.append(updatedInfo)
                    } else {
                        cachedComplete.append(info)
                    }
                }
            }
            
            // 使用更新后的缓存信息
            cachedInfos = cachedComplete
            
            // 将相册信息同步到缓存
            if !albumInfoMap.isEmpty {
                for index in 0..<cachedInfos.count {
                    let assetId = cachedInfos[index].assetIdentifier
                    if let info = albumInfoMap[assetId] {
                        cachedInfos[index].albumIdentifier = info.identifier
                        cachedInfos[index].albumName = info.name
                    }
                }
            }
            
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
        
        // 创建图片收集器（用于 AI 分析）
        let imageCollector = CompressedImageCollector()
        
        // 为缓存的照片也加载图片（用于 AI 分析）
        if enableCaching && !cachedInfos.isEmpty {
            NSLog("📸 为 \(cachedInfos.count) 张缓存照片加载图片（用于 AI 分析）...")
            for cachedInfo in cachedInfos {
                if let asset = assets.first(where: { $0.localIdentifier == cachedInfo.assetIdentifier }) {
                    // 加载图片但不重新分析颜色
                    await loadImageForAI(asset: asset, identifier: cachedInfo.assetIdentifier, imageCollector: imageCollector)
                }
            }
        }
        
        // 阶段1: 并发提取每张照片的主色（仅处理未缓存的）
        await withTaskGroup(of: (Int, PhotoColorInfo?).self) { group in
            var pendingCount = 0
            var nextIndex = 0
            
            // 启动初始批次的任务
            while nextIndex < assetsToProcess.count && pendingCount < maxConcurrentExtractions {
                let index = nextIndex
                let asset = assetsToProcess[index]
                let albumInfo = albumInfoMap[asset.localIdentifier]
                group.addTask { [albumInfo, imageCollector] in
                    let photoInfo = await self.extractPhotoColors(asset: asset, albumInfo: albumInfo, imageCollector: imageCollector)
                    return (index, photoInfo)
                }
                pendingCount += 1
                nextIndex += 1
            }
            
            // 实时处理结果，每完成一个就启动下一个
            while let (index, photoInfo) = await group.next() {
                // 处理完成的结果
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
                
                pendingCount -= 1
                
                // 如果还有未处理的照片，启动下一个任务
                if nextIndex < assetsToProcess.count {
                    let newIndex = nextIndex
                    let asset = assetsToProcess[newIndex]
                    let albumInfo = albumInfoMap[asset.localIdentifier]
                    group.addTask { [albumInfo, imageCollector] in
                        let photoInfo = await self.extractPhotoColors(asset: asset, albumInfo: albumInfo, imageCollector: imageCollector)
                        return (newIndex, photoInfo)
                    }
                    pendingCount += 1
                    nextIndex += 1
                }
            }
        }
        
        // ✅ 修复顺序问题：按照用户选择的原始顺序重新排序 photoInfos
        // 创建 assetIdentifier -> 原始索引的映射
        let originalOrderMap: [String: Int] = Dictionary(
            uniqueKeysWithValues: assets.enumerated().map { ($1.localIdentifier, $0) }
        )
        
        // 按原始顺序排序 photoInfos
        await MainActor.run {
            result.photoInfos.sort { info1, info2 in
                let index1 = originalOrderMap[info1.assetIdentifier] ?? Int.max
                let index2 = originalOrderMap[info2.assetIdentifier] ?? Int.max
                return index1 < index2
            }
        }
        
        // 获取收集的所有压缩图片（按照排序后的 photoInfos 顺序）
        let orderedIdentifiers = result.photoInfos.map { $0.assetIdentifier }
        let compressedImages = await imageCollector.getAll(orderedBy: orderedIdentifiers)
        
        // 💾 缓存压缩图片到 result 中，用于后续 AI 评价刷新
        await MainActor.run {
            result.compressedImages = compressedImages
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📦 图片收集完成")
            print("   - 收集到的压缩图片: \(compressedImages.count) 张")
            print("   - 总照片数: \(assets.count) 张")
            print("   - 缓存照片: \(cachedInfos.count) 张")
            print("   - 新分析照片: \(assetsToProcess.count) 张")
            print("   - ✅ 图片顺序: 与用户选择顺序一致")
            print("   - 💾 已缓存到 result.compressedImages")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
        
        // 🚀 图片收集完成后立即启动 AI 评价（不等待颜色聚类完成）
        let aiEvaluationTask = Task.detached(priority: .userInitiated) { [compressedImages] in
            await MainActor.run {
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("🎨 立即启动 AI 评价（Qwen3-VL-Flash）")
                print("   - 图片数量: \(compressedImages.count)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
            
            do {
                // 获取用户输入的感受
                let userMessage = await MainActor.run { result.userMessage }
                
                if let msg = userMessage, !msg.isEmpty {
                    await MainActor.run {
                        print("   - 用户感受: \(msg)")
                    }
                }
                
                let evaluation = try await self.aiEvaluator.evaluateColorAnalysis(
                    result: result,
                    compressedImages: compressedImages,
                    userMessage: userMessage,
                    onUpdate: { @MainActor updatedEvaluation in
                        // 实时更新 UI
                        result.aiEvaluation = updatedEvaluation
                    }
                )
                
                await MainActor.run {
                    result.aiEvaluation = evaluation
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print("✅ AI 评价完成")
                    if let text = evaluation.overallEvaluation?.fullText, !text.isEmpty {
                        print("   - 生成了 \(text.count) 个字符的评论")
                    }
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                }
                
                // 更新 Core Data 中的 AI 评价数据（等待 sessionId 可用）
                // 在后台循环等待 sessionId
                var waitCount = 0
                let maxWait = 60 // 最多等待 60 次（约 6 秒）
                while waitCount < maxWait {
                    let sessionId = await MainActor.run { result.sessionId }
                    if let sessionId = sessionId {
                        do {
                            try await self.coreDataManager.updateAIEvaluation(
                                sessionId: sessionId,
                                evaluation: evaluation
                            )
                            await MainActor.run {
                                print("💾 AI 评价已更新到 Core Data (sessionId: \(sessionId.uuidString))")
                            }
                        } catch {
                            await MainActor.run {
                                print("⚠️ 更新 AI 评价到 Core Data 失败: \(error)")
                            }
                        }
                        break
                    }
                    // 等待 100ms 后再检查
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    waitCount += 1
                }
                
                if waitCount >= maxWait {
                    await MainActor.run {
                        print("⚠️ 等待 sessionId 超时，AI 评价未保存到 Core Data")
                    }
                }
            } catch {
                await MainActor.run {
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print("❌ AI 评价失败")
                    print("   - 错误: \(error.localizedDescription)")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    // 创建一个带有错误信息的评价对象
                    var errorEvaluation = ColorEvaluation()
                    errorEvaluation.isLoading = false
                    errorEvaluation.error = error.localizedDescription
                    result.aiEvaluation = errorEvaluation
                }
            }
        }
        
        // Phase 5: 收集完成后，同步本地 photoInfos（包含缓存 + 新分析）
        photoInfos = result.photoInfos
        
        // 从所有照片（包括缓存）中收集主色用于聚类
        var allColorWeights: [Float] = []  // 新增：权重数组
        
        // 先从缓存的照片收集
        for photoInfo in cachedInfos {
            // 收集所有5个主色
            for color in photoInfo.dominantColors {
                let lab = converter.rgbToLab(color.rgb)
                allMainColorsLAB.append(lab)
                allColorWeights.append(color.weight)  // 收集权重
            }
        }
        
        // 再从新提取的照片收集
        for photoInfo in result.photoInfos where !cachedInfos.contains(where: { $0.assetIdentifier == photoInfo.assetIdentifier }) {
            // 收集所有5个主色
            for color in photoInfo.dominantColors {
                let lab = converter.rgbToLab(color.rgb)
                allMainColorsLAB.append(lab)
                allColorWeights.append(color.weight)  // 收集权重
            }
        }
        
        // 阶段2: 全局聚类（Phase 5: 并发自动选择最优K 或 使用手动K值）
        
        // 读取显影解析模式
        let developmentMode = BatchProcessSettings.developmentMode
        let analysisMode: DevelopmentAnalysisMode = {
            switch developmentMode {
            case .tone:
                return .tone
            case .shadow, .comprehensive:
                return .comprehensive
            }
        }()
        let modeDesc = analysisMode == .tone ? "色调模式" : "综合模式"
        print("   🎨 显影解析模式: \(modeDesc)")
        
        // 自动选择最优 K 值
        let clusteringResult: SimpleKMeans.ClusteringResult
        
        await MainActor.run {
                // 计算K值选择的预计时间（约6-8秒）
                let elapsed = Date().timeIntervalSince(startTime)
                let kSelectionTime: TimeInterval = 7.0  // K值选择预计7秒
                let remainingTime = kSelectionTime + 3.0  // +3秒用于后续处理
                
                var progress = AnalysisProgress(
                    currentPhoto: assets.count,
                    totalPhotos: assets.count,
                    currentStage: "自动选择最优色系数",
                    overallProgress: 0.72,
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
            // Phase 5: 优化小数据集的K值范围
            // 对于少量照片，允许更多簇以捕捉细微差异
            let maxK: Int
            if allMainColorsLAB.count < 20 {
                // 少于20个颜色点（约4张照片）：最多6个簇
                maxK = max(minK, min(6, allMainColorsLAB.count / 3))
            } else if allMainColorsLAB.count < 50 {
                // 20-50个颜色点（约4-10张照片）：最多8个簇
                maxK = max(minK, min(8, allMainColorsLAB.count / 5))
            } else {
                // 50+个颜色点（10+张照片）：最多12个簇
                maxK = max(minK, min(12, allMainColorsLAB.count / 10))
            }
            
            print("   颜色点数: \(allMainColorsLAB.count)")
            print("   K值范围: \(minK) - \(maxK)")
            
            guard let kResult = await autoKSelector.findOptimalKConcurrent(
                points: allMainColorsLAB,
                config: AutoKSelector.Config(
                    minK: minK,
                    maxK: maxK,
                    maxIterations: 50,
                    colorSpace: .lab,
                    weights: allColorWeights,  // 传递权重
                    analysisMode: analysisMode  // 传递解析模式
                ),
                progressHandler: { currentK, totalK in
                    Task { @MainActor in
                        progressHandler(AnalysisProgress(
                            currentPhoto: assets.count,
                            totalPhotos: assets.count,
                            currentStage: "自动选择最优色系数（并发）",
                            overallProgress: 0.72 + 0.06 * Double(currentK) / Double(totalK),  // 72%-78%
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
            clusteringResult = kResult.bestClustering
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
                    overallProgress: 0.78,  // 聚类阶段
                    failedCount: result.failedCount
                ))
            }
        
        // 使用聚类结果（已在上面获取）
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
                        overallProgress: 0.80,  // 聚类完成，开始计算结果
                        failedCount: result.failedCount
                    ))
                }
            
            // Phase 2: 使用 LAB 质心进行分配
            for i in 0..<photoInfos.count {
                assignPhotoToCluster(
                    photoInfo: &photoInfos[i],
                    clusters: clusters,
                    centroidsLAB: centroidsLAB,
                    analysisMode: analysisMode
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
            
            // Phase 5: 自适应聚类更新（使用用户设置）
            if settings.effectiveEnableAdaptiveClustering {
                await MainActor.run {
                    progressHandler(AnalysisProgress(
                        currentPhoto: assets.count,
                        totalPhotos: assets.count,
                        currentStage: "优化聚类结果",
                        overallProgress: 0.81,  // 优化聚类
                        failedCount: result.failedCount,
                        cachedCount: cachedInfos.count,
                        isConcurrent: false
                    ))
                }
                
                // Phase 5: 使用默认配置
                // 统一设为 2（默认值），保留至少有 2 张照片的簇
                let dynamicMinClusterSize = settings.effectiveMinClusterSize
                
                let adaptiveConfig = AdaptiveClusterManager.Config(
                    mergeThresholdDeltaE: settings.effectiveMergeThreshold,
                    minClusterSize: dynamicMinClusterSize,
                    splitThresholdIntraDist: 40.0,
                    useColorNameSimilarity: settings.effectiveUseColorNameSimilarity
                )
                
                print("📊 自适应聚类配置:")
                print("   - 照片数量: \(assets.count)")
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
                
                // Phase 5: 根据自适应更新后的簇，更新照片的 primaryClusterIndex
                // 构建 assetIdentifier → clusterIndex 的映射
                var photoToClusterMap: [String: Int] = [:]
                for cluster in updatedClusters {
                    for photoId in cluster.photoIdentifiers {
                        photoToClusterMap[photoId] = cluster.index
                    }
                }
                
                // 更新 photoInfos 中的 primaryClusterIndex
                for i in 0..<photoInfos.count {
                    if let newClusterIndex = photoToClusterMap[photoInfos[i].assetIdentifier] {
                        photoInfos[i].primaryClusterIndex = newClusterIndex
                    } else {
                        print("⚠️ 警告: 照片 \(photoInfos[i].assetIdentifier.prefix(8))... 未分配到任何簇")
                    }
                }
                
                // 更新进度以显示自适应操作
                await MainActor.run {
                    var finalProgress = AnalysisProgress(
                        currentPhoto: assets.count,
                        totalPhotos: assets.count,
                        currentStage: "优化聚类结果",
                        overallProgress: 0.82,  // 优化完成
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
        
        // 按照原始 assets 顺序排序 photoInfos，确保顺序与用户选择时一致
        let assetOrder = Dictionary(uniqueKeysWithValues: assets.enumerated().map { ($0.element.localIdentifier, $0.offset) })
        photoInfos.sort { (a, b) -> Bool in
            let orderA = assetOrder[a.assetIdentifier] ?? Int.max
            let orderB = assetOrder[b.assetIdentifier] ?? Int.max
            return orderA < orderB
        }
        
        result.photoInfos = photoInfos
        result.isCompleted = true
        
        // 冷暖色调分布计算已禁用
        // await MainActor.run {
        //     progressHandler(AnalysisProgress(
        //         currentPhoto: assets.count,
        //         totalPhotos: assets.count,
        //         currentStage: "计算冷暖色调分布",
        //         overallProgress: 0.83,
        //         failedCount: result.failedCount,
        //         cachedCount: cachedInfos.count
        //     ))
        // }
        // 
        // print("🌡️ 计算冷暖色调分布...")
        // print("   - 照片总数: \(photoInfos.count)")
        // 
        // let photosWithScores = photoInfos.filter { $0.advancedColorAnalysis != nil }
        // print("   - 有评分的照片: \(photosWithScores.count)")
        // 
        // let warmCoolDistribution = warmCoolCalculator.calculateDistribution(photoInfos: photoInfos)
        // await MainActor.run {
        //     result.warmCoolDistribution = warmCoolDistribution
        // }
        // 
        // await MainActor.run {
        //     progressHandler(AnalysisProgress(
        //         currentPhoto: assets.count,
        //         totalPhotos: assets.count,
        //         currentStage: "冷暖色调分析完成",
        //         overallProgress: 0.84,
        //         failedCount: result.failedCount,
        //         cachedCount: cachedInfos.count
        //     ))
        // }
        // 
        // print("✅ 冷暖色调分布计算完成")
        // print("   - 直方图档数: \(warmCoolDistribution.histogram.count)")
        // print("   - 评分数据: \(warmCoolDistribution.scores.count)")
        
        // 完成（进度留给 AI 等待阶段）
        await MainActor.run {
            progressHandler(AnalysisProgress(
                currentPhoto: assets.count,
                totalPhotos: assets.count,
                currentStage: "准备 AI 分析",
                overallProgress: 0.85,  // 留出 85%-100% 给 AI 等待阶段
                failedCount: result.failedCount
            ))
        }
        
        // Phase 3: 保存到 Core Data (后台线程) - 必须先完成，以便 AI 评价能获取 sessionId
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("💾 准备保存到 Core Data")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let saveTask = Task.detached(priority: .background) {
            do {
                print("📝 开始保存分析结果到Core Data...")
                print("   - clusters: \(result.clusters.count)")
                print("   - photoInfos: \(result.photoInfos.count)")
                
                let savedInfo = try self.coreDataManager.saveAnalysisSession(from: result)
                
                print("💾 saveAnalysisSession 返回:")
                print("   - id: \(savedInfo.id?.uuidString ?? "nil")")
                print("   - name: \(savedInfo.name ?? "nil")")
                
                await MainActor.run {
                    // 将 sessionId 设置到 result 中
                    result.sessionId = savedInfo.id
                    
                    print("✅ 分析结果已保存到Core Data")
                    print("   - Session ID: \(savedInfo.id?.uuidString ?? "nil")")
                    print("   - result.sessionId 已设置为: \(result.sessionId?.uuidString ?? "nil")")
                    print("   - 名称: \(savedInfo.name ?? "未命名")")
                    print("   - 日期: \(savedInfo.date ?? Date())")
                }
            } catch {
                await MainActor.run {
                    print("⚠️ 保存分析结果失败: \(error)")
                    print("   错误详情: \(error.localizedDescription)")
                }
            }
        }
        
        // 等待保存完成
        print("⏳ 等待保存任务完成...")
        await saveTask.value
        print("✅ 保存任务已完成")
        print("   - result.sessionId 当前值: \(result.sessionId?.uuidString ?? "nil")")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 风格分析（后台线程，不阻塞主流程）
        // 注意：AI 评价已在图片收集完成后立即启动（aiEvaluationTask）
        Task.detached(priority: .background) {
        await MainActor.run {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("📊 启动后台风格分析")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
        
                await self.performStyleAnalysis(
                    result: result,
                    photoInfos: photoInfos,
                    progressHandler: progressHandler
                )
            
            await MainActor.run {
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("✅ 风格分析完成")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
        }
        
        // 等待 AI 评价任务完成（确保在返回前 AI 已开始输出）
        // 不需要等待完成，因为 HomeView 会监听 aiEvaluation 的变化
        _ = aiEvaluationTask
        
        return result
    }
    
    // MARK: - 辅助方法
    
    /// 计算基于最长边的目标尺寸（保持宽高比）
    /// - Parameter maxDimension: 最长边的像素值（默认 400）
    /// - Returns: 目标尺寸（最长边为 maxDimension，保持宽高比）
    private func calculateTargetSize(for asset: PHAsset, maxDimension: CGFloat = 400) -> CGSize {
        let width = CGFloat(asset.pixelWidth)
        let height = CGFloat(asset.pixelHeight)
        
        guard width > 0 && height > 0 else {
            // 如果无法获取尺寸，返回默认值
            return CGSize(width: maxDimension, height: maxDimension)
        }
        
        // 确定最长边
        let longestSide = max(width, height)
        
        // 如果图片已经小于目标尺寸，使用原尺寸
        if longestSide <= maxDimension {
            return CGSize(width: width, height: height)
        }
        
        // 计算缩放比例（基于最长边）
        let scale = maxDimension / longestSide
        
        // 计算缩放后的尺寸（保持宽高比）
        let targetWidth = width * scale
        let targetHeight = height * scale
        
        // 验证：最长边应该是 maxDimension
        let resultLongestSide = max(targetWidth, targetHeight)
        assert(abs(resultLongestSide - maxDimension) < 1.0, "计算错误：最长边应为 \(maxDimension)，实际为 \(resultLongestSide)")
        
        return CGSize(width: targetWidth, height: targetHeight)
    }
    
    // MARK: - 为缓存的照片更新元数据（冷暖评分和 Vision 分析已禁用）
    private func updateWarmCoolScore(asset: PHAsset, photoInfo: PhotoColorInfo) async -> PhotoColorInfo? {
        #if canImport(UIKit)
        // 冷暖评分和 Vision 分析已禁用，只读取元数据
        let metadata = await self.metadataReader.readMetadata(from: asset)
        
        var updatedInfo = photoInfo
        // updatedInfo.advancedColorAnalysis = score  // 冷暖评分已禁用
        // updatedInfo.visionInfo = vision  // Vision 分析已禁用
        updatedInfo.metadata = metadata
        
        return updatedInfo
        #else
        return nil
        #endif
    }
    
    // MARK: - 为 AI 分析加载图片（不进行颜色分析）
    private func loadImageForAI(
        asset: PHAsset,
        identifier: String,
        imageCollector: CompressedImageCollector
    ) async {
        #if canImport(UIKit)
        let loadedImage = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            var hasResumed = false  // ✅ 防止重复 resume
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            
            // 计算目标尺寸：最长边400，保持宽高比
            let targetSize = self.calculateTargetSize(for: asset, maxDimension: 400)
            
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
        
        if let image = loadedImage {
            await imageCollector.append(image, identifier: identifier)
        }
        #endif
    }
    
    // MARK: - 提取单张照片的主色
    private func extractPhotoColors(
        asset: PHAsset,
        albumInfo: (identifier: String, name: String)?,
        imageCollector: CompressedImageCollector? = nil
    ) async -> PhotoColorInfo? {
        #if canImport(UIKit)
        // 第一步：快速获取图像（在 PHImageManager 回调中只做最少的工作）
        let loadedImage = await withCheckedContinuation { (continuation: CheckedContinuation<(UIImage, CGImage)?, Never>) in
            var hasResumed = false  // ✅ 防止重复 resume
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            
            // 计算目标尺寸：最长边400，保持宽高比
            let targetSize = self.calculateTargetSize(for: asset, maxDimension: 400)
            NSLog("📐 照片 \(asset.localIdentifier.prefix(8))... 原始尺寸: \(asset.pixelWidth)x\(asset.pixelHeight), 目标尺寸: \(Int(targetSize.width))x\(Int(targetSize.height))")
            
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                hasResumed = true
                
                if let image = image, let cgImage = image.cgImage {
                    NSLog("   ✓ 实际加载尺寸: \(Int(image.size.width))x\(Int(image.size.height)), CGImage: \(cgImage.width)x\(cgImage.height)")
                    continuation.resume(returning: (image, cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        
        guard let (image, cgImage) = loadedImage else {
            return nil
        }
        
        // 收集压缩图片（用于 AI 分析）
        if let collector = imageCollector {
            await collector.append(image, identifier: asset.localIdentifier)
        }
        
        // 第二步：在后台线程执行所有耗时操作
        return await Task.detached(priority: .userInitiated) {
            // 根据用户设置构建配置
            let algorithm: SimpleColorExtractor.Config.Algorithm =
                self.settings.effectiveColorExtractionAlgorithm == .labWeighted
                    ? .labWeighted
                    : .medianCut
            
            let quality: SimpleColorExtractor.Config.Quality
            switch self.settings.effectiveExtractionQuality {
            case .fast:
                quality = .fast
            case .balanced:
                quality = .balanced
            case .fine:
                quality = .fine
            }
            
            let config = SimpleColorExtractor.Config(
                algorithm: algorithm,
                quality: quality,
                autoMergeSimilarColors: self.settings.effectiveAutoMergeSimilarColors
            )
            
            // 提取主色和亮度 CDF（使用配置）
            let extractionResult = self.colorExtractor.extractDominantColorsWithCDF(
                from: cgImage,
                count: 5,
                config: config
            )
            
            // 命名主色
            var namedColors = extractionResult.dominantColors
            for i in 0..<namedColors.count {
                namedColors[i].colorName = self.colorNamer.getColorName(rgb: namedColors[i].rgb)
            }
            
            // 创建 PhotoColorInfo
            var photoInfo = PhotoColorInfo(
                assetIdentifier: asset.localIdentifier,
                dominantColors: namedColors,
                brightnessCDF: extractionResult.brightnessCDF
            )
            
            // ✅ 计算视觉代表色（5个主色在 LAB 空间的加权平均）
            photoInfo.computeVisualRepresentativeColor()
            
            // ✅ 计算明度中位数和对比度（从 CDF）
            photoInfo.computeBrightnessStatistics()
            
            // 调试日志
            let cdf = extractionResult.brightnessCDF
            if !cdf.isEmpty {
                print("✅ 照片 \(asset.localIdentifier.prefix(8))... CDF 数据已生成（\(cdf.count) 个值）")
            } else {
                print("⚠️ 照片 \(asset.localIdentifier.prefix(8))... CDF 数据为空")
            }
            
            // 设置相册信息
            photoInfo.albumIdentifier = albumInfo?.identifier
            photoInfo.albumName = albumInfo?.name
            if let albumInfo = albumInfo {
                print("   📂 记录相册: \(albumInfo.name) → 照片 \(asset.localIdentifier.prefix(8))...")
            }
            
            // 读取元数据（冷暖评分和 Vision 分析已禁用）
            // async let warmCoolScore = self.warmCoolCalculator.calculateScore(
            //     image: cgImage,
            //     dominantColors: namedColors
            // )
            // async let visionInfo = self.visionAnalyzer.analyzeImage(image)
            
            async let metadata = self.metadataReader.readMetadata(from: asset)
            
            // 等待元数据读取完成
            let meta = await metadata
            
            // photoInfo.advancedColorAnalysis = score  // 冷暖评分已禁用
            // photoInfo.visionInfo = vision  // Vision 分析已禁用
            photoInfo.metadata = meta
            
            // print("🌡️ 照片 \(asset.localIdentifier.prefix(8))... 冷暖评分: \(score.overallScore)")
            // print("🔍 照片 \(asset.localIdentifier.prefix(8))... Vision 分析完成")
            if meta != nil {
                print("📸 照片 \(asset.localIdentifier.prefix(8))... 元数据读取完成")
            }
            
            return photoInfo
        }.value
        #else
        return nil
        #endif
    }
    
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
    
    // MARK: - 为照片分配主簇（Phase 2: 使用 LAB 空间）
    private func assignPhotoToCluster(
        photoInfo: inout PhotoColorInfo,
        clusters: [ColorCluster],
        centroidsLAB: [SIMD3<Float>],
        analysisMode: DevelopmentAnalysisMode = .comprehensive
    ) {
        // 计算每个主色到各个簇的距离（LAB 空间）
        var clusterScores = [Int: Double]()
        
        for dominantColor in photoInfo.dominantColors {
            // 转换为 LAB
            let colorLAB = converter.rgbToLab(dominantColor.rgb)
            
            var minDistance = Float.greatestFiniteMagnitude
            var closestCluster = 0
            
            // 使用距离计算（根据模式选择）
            for (index, centroidLAB) in centroidsLAB.enumerated() {
                let distance = calculateDistance(colorLAB, centroidLAB, analysisMode: analysisMode)
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
        
        // 更新进度（节流：每 3 张照片或最后一张才更新）
        let counts = await tracker.getCounts()
        let currentCount = counts.processed + counts.failed
        let shouldUpdate = (currentCount % 3 == 0) || (currentCount == totalPhotos)
        
        if shouldUpdate {
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
    
    // MARK: - 风格分析（后台）
    
    /// 执行风格分析（在后台线程运行，不阻塞主流程）
    private func performStyleAnalysis(
        result: AnalysisResult,
        photoInfos: [PhotoColorInfo],
        progressHandler: @escaping (AnalysisProgress) -> Void
    ) async {
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎨 开始风格分析（后台）")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 1. 计算每张照片的 ImageFeature
        var imageFeatures: [ImageFeature] = []
        var processedCount = 0
        
        for var photoInfo in photoInfos {
            // 检查是否有冷暖评分数据
            guard let advancedColorAnalysis = photoInfo.advancedColorAnalysis,
                  let slicData = advancedColorAnalysis.slicData,
                  let hslData = advancedColorAnalysis.hslData else {
                print("⚠️ 照片 \(photoInfo.assetIdentifier.prefix(8))... 缺少 SLIC/HSL 数据，跳过")
                continue
            }
            
            // 转换数据格式
            let slicInput = ImageStatisticsCalculator.SLICData(
                labBuffer: slicData.labBuffer,
                labels: slicData.labels,
                width: slicData.width,
                height: slicData.height
            )
            
            let hslInput = ImageStatisticsCalculator.HSLData(
                hslList: hslData.tuples
            )
            
            // 计算 ImageFeature
            let imageFeature = imageStatisticsCalculator.calculateImageFeature(
                slicData: slicInput,
                hslData: hslInput,
                dominantColors: photoInfo.dominantColors,
                coolWarmScore: advancedColorAnalysis.overallScore
            )
            
            imageFeatures.append(imageFeature)
            
            // 更新 photoInfo（注意：需要更新 result.photoInfos）
            if let index = await MainActor.run(body: {
                result.photoInfos.firstIndex(where: { $0.assetIdentifier == photoInfo.assetIdentifier })
            }) {
                await MainActor.run {
                    result.photoInfos[index].imageFeature = imageFeature
                }
            }
            
            processedCount += 1
            
            // 每 10 张照片打印一次进度
            if processedCount % 10 == 0 {
                print("   已处理 \(processedCount)/\(photoInfos.count) 张照片的风格特征")
            }
        }
        
        print("✅ 图像特征计算完成: \(imageFeatures.count) 张")
        
        // 2. 聚合 CollectionFeature
        guard !imageFeatures.isEmpty else {
            print("⚠️ 没有有效的图像特征，跳过作品集聚合")
            return
        }
        
        print("📊 开始聚合作品集特征...")
        
        let clusters = await MainActor.run { result.clusters }
        let collectionFeature = collectionFeatureCalculator.aggregateCollectionFeature(
            imageFeatures: imageFeatures,
            globalPalette: clusters
        )
        
        await MainActor.run {
            result.collectionFeature = collectionFeature
        }
        
        print("✅ 作品集特征聚合完成")
        print("   - 亮度分布: \(collectionFeature.brightnessDistribution.rawValue)")
        print("   - 对比度分布: \(collectionFeature.contrastDistribution.rawValue)")
        print("   - 饱和度分布: \(collectionFeature.saturationDistribution.rawValue)")
        print("   - 平均冷暖分数: \(String(format: "%.3f", collectionFeature.meanCoolWarmScore))")
        // 情绪和风格标签已删除，不再打印
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎉 风格分析完成")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    // MARK: - 隐私模式分析方法
    /// 隐私模式：直接使用 UIImage 数组进行分析，不使用 PHAsset
    /// 适用于通过 PhotosPicker 选择的照片
    func analyzePhotos(
        images: [UIImage],
        identifiers: [String],
        metadata: [PhotoMetadata] = [],
        userMessage: String? = nil,
        progressHandler: @escaping (AnalysisProgress) -> Void
    ) async -> AnalysisResult {
        
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        NSLog("🎨 开始颜色分析（隐私模式）")
        NSLog("   照片数量: \(images.count)")
        if let msg = userMessage, !msg.isEmpty {
            NSLog("   用户感受: \(msg)")
        }
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let result = AnalysisResult()
        result.totalPhotoCount = images.count
        result.timestamp = Date()
        
        // 设置用户输入的感受
        if let msg = userMessage, !msg.isEmpty {
            result.userMessage = msg
        }
        
        var allMainColorsLAB: [SIMD3<Float>] = []
        var photoInfos: [PhotoColorInfo] = []
        
        let startTime = Date()
        
        // Phase 1: 并发提取所有照片的颜色
        let progressTracker = ProgressTracker(initialCount: 0)
        let compressedImageCollector = CompressedImageCollector()
        
        await withTaskGroup(of: (PhotoColorInfo?, UIImage?, String).self) { group in
            for (index, image) in images.enumerated() {
                let identifier = identifiers[index]
                
                group.addTask {
                    let photoStartTime = Date()
                    
                    // 报告开始处理
                    let currentProgress = await progressTracker.getCounts().processed
                    let progress = AnalysisProgress(
                        currentPhoto: currentProgress + 1,
                        totalPhotos: images.count,
                        currentStage: "正在分析第 \(currentProgress + 1) 张照片...",
                        overallProgress: Double(currentProgress) / Double(images.count) * 0.7
                    )
                    progressHandler(progress)
                    
                    // 提取颜色
                    guard let cgImage = image.cgImage else {
                        await progressTracker.incrementFailed()
                        return (nil, nil, identifier)
                    }
                    
                    // 构建与常规管线一致的配置
                    let algorithm: SimpleColorExtractor.Config.Algorithm =
                        self.settings.effectiveColorExtractionAlgorithm == .labWeighted
                            ? .labWeighted
                            : .medianCut
                    
                    let quality: SimpleColorExtractor.Config.Quality
                    switch self.settings.effectiveExtractionQuality {
                    case .fast:
                        quality = .fast
                    case .balanced:
                        quality = .balanced
                    case .fine:
                        quality = .fine
                    }
                    
                    let config = SimpleColorExtractor.Config(
                        algorithm: algorithm,
                        quality: quality,
                        autoMergeSimilarColors: self.settings.effectiveAutoMergeSimilarColors
                    )
                    
                    // 提取主色与亮度分布
                    let extractionResult = self.colorExtractor.extractDominantColorsWithCDF(
                        from: cgImage,
                        count: 5,
                        config: config
                    )
                    
                    // 命名主色
                    var dominantColors = extractionResult.dominantColors
                    for i in 0..<dominantColors.count {
                        dominantColors[i].colorName = self.colorNamer.getColorName(rgb: dominantColors[i].rgb)
                    }
                    
                    // Vision 识别（隐私模式下默认关闭）
                    let visionInfo: PhotoVisionInfo? = nil
                    
                    // 创建 PhotoColorInfo
                    var info = PhotoColorInfo(
                        assetIdentifier: identifier,
                        dominantColors: dominantColors,
                        brightnessCDF: extractionResult.brightnessCDF
                    )
                    
                    // 计算衍生数据
                    info.computeVisualRepresentativeColor()
                    info.computeBrightnessStatistics()
                    info.visionInfo = visionInfo
                    
                    // 设置元数据（如果有）
                    if index < metadata.count {
                        info.metadata = metadata[index]
                        if metadata[index].cameraMake != nil {
                            print("📸 照片 \(identifier.prefix(8))... 已关联元数据")
                        }
                    }
                    
                    // 压缩图片用于保存（优化：从 800px 降低到 400px 以加快 AI 分析）
                    let compressedImage = self.compressImage(image, maxDimension: 400)
                    
                    await progressTracker.incrementProcessed()
                    
                    let elapsed = Date().timeIntervalSince(photoStartTime)
                    NSLog("✅ 照片 \(currentProgress + 1) 分析完成，耗时 \(String(format: "%.2f", elapsed)) 秒")
                    
                    return (info, compressedImage, identifier)
                }
            }
            
            // 收集结果
            for await (info, compressedImage, identifier) in group {
                if let info = info {
                    photoInfos.append(info)
                    allMainColorsLAB.append(contentsOf: info.dominantColors.map { self.converter.rgbToLab($0.rgb) })
                    
                    if let compressedImage = compressedImage {
                        await compressedImageCollector.append(compressedImage, identifier: identifier)
                    }
                }
            }
        }
        
        let (processedCount, failedCount) = await progressTracker.getCounts()
        NSLog("📊 颜色提取完成: 成功 \(processedCount) 张，失败 \(failedCount) 张")
        result.photoInfos = photoInfos
        result.processedCount = processedCount
        result.failedCount = failedCount
        
        guard !photoInfos.isEmpty else {
            NSLog("❌ 没有成功提取的照片")
            return result
        }
        
        // 更新进度
        progressHandler(AnalysisProgress(
            currentPhoto: images.count,
            totalPhotos: images.count,
            currentStage: "正在聚类分析...",
            overallProgress: 0.75
        ))
        
        // Phase 2: 聚类分析
        // 收集所有主色点与权重
        var allColorWeights: [Float] = []
        allMainColorsLAB.removeAll(keepingCapacity: true)
        for info in photoInfos {
            for color in info.dominantColors {
                allMainColorsLAB.append(self.converter.rgbToLab(color.rgb))
                allColorWeights.append(color.weight)
            }
        }
        
        // 选择 K 值（并发）
        let minK = 3
        let maxK = max(minK, min(12, max(1, allMainColorsLAB.count / 3)))
        var clusteringResult: SimpleKMeans.ClusteringResult?
        
        if let kResult = await autoKSelector.findOptimalKConcurrent(
            points: allMainColorsLAB,
            config: AutoKSelector.Config(
                minK: minK,
                maxK: maxK,
                maxIterations: 50,
                colorSpace: .lab,
                weights: allColorWeights,
                analysisMode: .comprehensive
            )
        ) {
            clusteringResult = kResult.bestClustering
            result.optimalK = kResult.optimalK
            result.silhouetteScore = kResult.silhouetteScore
            result.qualityLevel = kResult.qualityLevel.rawValue
            result.qualityDescription = kResult.qualityDescription
            result.allKScores = kResult.allScores
        } else {
            // 回退到固定 K
            clusteringResult = kmeans.cluster(
                points: allMainColorsLAB,
                k: minK,
                maxIterations: 50,
                colorSpace: .lab,
                weights: allColorWeights,
                analysisMode: .comprehensive
            )
            result.optimalK = minK
        }
        
        guard let clusteringResult else {
            NSLog("❌ 聚类失败")
            return result
        }
        
        // 创建聚类结果
        var clusters: [ColorCluster] = []
        let centroidsLAB = clusteringResult.centroids
        for (index, centroidLAB) in centroidsLAB.enumerated() {
            let centroidRGB = converter.labToRgb(centroidLAB)
            let colorName = colorNamer.getColorName(lab: centroidLAB)
            clusters.append(ColorCluster(
                index: index,
                centroid: centroidRGB,
                colorName: colorName
            ))
        }
        
        // 为照片分配簇
        for i in 0..<photoInfos.count {
            assignPhotoToCluster(
                photoInfo: &photoInfos[i],
                clusters: clusters,
                centroidsLAB: centroidsLAB,
                analysisMode: .comprehensive
            )
        }
        
        // 统计簇信息
        for i in 0..<clusters.count {
            let photosInCluster = photoInfos.filter { $0.primaryClusterIndex == i }
            clusters[i].photoCount = photosInCluster.count
            clusters[i].photoIdentifiers = photosInCluster.map { $0.assetIdentifier }
        }
        
        // 按照片数量排序簇，并重新映射索引
        clusters.sort { $0.photoCount > $1.photoCount }
        var oldToNewIndex: [Int: Int] = [:]
        for (newIndex, cluster) in clusters.enumerated() {
            oldToNewIndex[cluster.index] = newIndex
        }
        
        for i in 0..<photoInfos.count {
            if let oldIndex = photoInfos[i].primaryClusterIndex,
               let newIndex = oldToNewIndex[oldIndex] {
                photoInfos[i].primaryClusterIndex = newIndex
            }
        }
        
        for i in 0..<clusters.count {
            clusters[i].index = i
            let photosInCluster = photoInfos.filter { $0.primaryClusterIndex == i }
            clusters[i].photoCount = photosInCluster.count
            clusters[i].photoIdentifiers = photosInCluster.map { $0.assetIdentifier }
        }
        
        result.clusters = clusters
        result.isCompleted = true
        
        NSLog("🎨 聚类完成: K=\(clusters.count), 生成 \(clusters.count) 个色板")
        
        // Phase 3: 保存到 Core Data
        progressHandler(AnalysisProgress(
            currentPhoto: images.count,
            totalPhotos: images.count,
            currentStage: "正在保存数据...",
            overallProgress: 0.85
        ))
        
        let orderedIdentifiers = photoInfos.map { $0.assetIdentifier }
        let compressedImages = await compressedImageCollector.getAll(orderedBy: orderedIdentifiers)
        result.compressedImages = compressedImages
        
        // 💾 保存原图（用于全屏查看）
        result.originalImages = images
        
        NSLog("📦 图片收集完成")
        NSLog("   - 压缩图片: \(compressedImages.count) 张")
        NSLog("   - 原图: \(images.count) 张")
        
        let saveTask = Task.detached(priority: .background) {
            do {
                let saved = try self.coreDataManager.saveAnalysisSession(from: result)
                await MainActor.run {
                    result.sessionId = saved.id
                    NSLog("💾 数据已保存，Session ID: \(saved.id?.uuidString ?? "nil")")
                }
            } catch {
                await MainActor.run {
                    NSLog("⚠️ 保存数据失败: \(error.localizedDescription)")
                }
            }
        }
        _ = await saveTask.value
        
        // Phase 4: 作品集特征聚合
        let collectionFeature = collectionFeatureCalculator.aggregateCollectionFeature(
            imageFeatures: [],
            globalPalette: clusters
        )
        
        await MainActor.run {
            result.collectionFeature = collectionFeature
        }
        
        // Phase 5: AI 评价（异步）
        progressHandler(AnalysisProgress(
            currentPhoto: images.count,
            totalPhotos: images.count,
            currentStage: "AI 正在生成评价...",
            overallProgress: 0.90
        ))
        
        Task {
            do {
                let evaluation = try await self.aiEvaluator.evaluateColorAnalysis(
                    result: result,
                    compressedImages: compressedImages,
                    userMessage: userMessage,
                    onUpdate: { @MainActor updated in
                        result.aiEvaluation = updated
                    }
                )
                
                await MainActor.run {
                    result.aiEvaluation = evaluation
                }
                
                if let sessionId = result.sessionId {
                    try? self.coreDataManager.updateAnalysisSessionAI(
                        sessionId: sessionId,
                        evaluation: evaluation
                    )
                }
            } catch {
                await MainActor.run {
                    var errorEvaluation = ColorEvaluation()
                    errorEvaluation.error = error.localizedDescription
                    errorEvaluation.isLoading = false
                    result.aiEvaluation = errorEvaluation
                }
                
                if let sessionId = result.sessionId {
                    var errorEvaluation = ColorEvaluation()
                    errorEvaluation.error = error.localizedDescription
                    errorEvaluation.isLoading = false
                    try? self.coreDataManager.updateAnalysisSessionAI(
                        sessionId: sessionId,
                        evaluation: errorEvaluation
                    )
                }
            }
        }
        
        let totalElapsed = Date().timeIntervalSince(startTime)
        NSLog("⏱️ 总耗时: \(String(format: "%.2f", totalElapsed)) 秒")
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        NSLog("🎉 分析完成（隐私模式）")
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        return result
    }
    
    // MARK: - 辅助方法
    /// 压缩图片
    private func compressImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        
        if scale >= 1.0 {
            return image
        }
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
