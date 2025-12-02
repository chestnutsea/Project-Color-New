//
//  CoreDataManager.swift
//  Project_Color
//
//  Created by ChatGPT on 2025/11/8.
//

import CoreData
import Foundation

final class CoreDataManager {

    static let shared = CoreDataManager()

    static let preview: CoreDataManager = {
        let manager = CoreDataManager(inMemory: true, shouldSeedPreview: true)
        return manager
    }()

    let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    private init(inMemory: Bool = false, shouldSeedPreview: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Project_Color")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        configure(context: container.viewContext, name: "viewContext")
        container.viewContext.automaticallyMergesChangesFromParent = true

        if shouldSeedPreview {
            seedPreviewData()
        }
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        configure(context: context, name: "backgroundContext")
        return context
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            self.configure(context: context, name: "performBackgroundTaskContext")
            block(context)
        }
    }

    @discardableResult
    func save(context: NSManagedObjectContext? = nil) throws -> Bool {
        let contextToSave = context ?? viewContext
        guard contextToSave.hasChanges else { return false }
        try contextToSave.save()
        return true
    }

    private func configure(context: NSManagedObjectContext, name: String) {
        context.name = name
        context.transactionAuthor = "ProjectColor"
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
    }

    private func seedPreviewData() {
        let context = viewContext

        (0..<3).forEach { index in
            let photo = PhotoEntity(context: context)
            photo.id = UUID()
            photo.assetLocalId = "preview-\(index)"
            photo.timestamp = Date().addingTimeInterval(Double(-index) * 3600)
            photo.toneCategory = index % 2 == 0 ? "warm" : "cool"
            photo.sceneLabel = index % 2 == 0 ? "outdoor" : "indoor"
            photo.styleLabel = index % 2 == 0 ? "复古" : "奶油"

            let style = StyleEntity(context: context)
            style.id = UUID()
            style.label = index % 2 == 0 ? "Vintage" : "Creamy"
            style.sourceModel = "Demo"
            style.confidence = 0.8
            style.addToPhotos(photo)

            let swatch = ColorSwatchEntity(context: context)
            swatch.id = UUID()
            swatch.hex = index % 2 == 0 ? "#F2D7D5" : "#D4E6F1"
            swatch.l = 60 + Double(index) * 5
            swatch.a = 5 + Double(index)
            swatch.b = 10 + Double(index) * 2
            swatch.ratio = 0.35 + Double(index) * 0.1
            swatch.photo = photo

            let feature = FeatureEntity(context: context)
            feature.id = UUID()
            feature.modelSource = "CLIP"
            feature.dimension = 3
            feature.vector = PhotoFeature.encode(vector: [0.1 * Float(index + 1),
                                                          0.2 * Float(index + 1),
                                                          0.3 * Float(index + 1)])
            feature.photo = photo
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Failed seeding preview data: \(error)")
        }
    }
    
    // MARK: - Phase 3: 分析会话管理
    
    /// 保存分析结果到Core Data（使用后台上下文）
    /// - Parameters:
    ///   - result: 分析结果
    ///   - context: 可选的上下文
    /// - Returns: 保存的会话实体
    func saveAnalysisSession(
        from result: AnalysisResult,
        context: NSManagedObjectContext? = nil
    ) throws -> (id: UUID?, name: String?, date: Date?) {
        // 使用后台上下文避免阻塞主线程
        let ctx = context ?? container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // 在主线程提取所有需要的数据，避免在后台上下文中访问ObservableObject
        let timestamp = result.timestamp
        let totalPhotoCount = result.totalPhotoCount
        let processedCount = result.processedCount
        let failedCount = result.failedCount
        let optimalK = result.optimalK
        let silhouetteScore = result.silhouetteScore
        let isCompleted = result.isCompleted
        let clusters = result.clusters
        let photoInfos = result.photoInfos
        
        var savedSession: AnalysisSessionEntity!
        var saveError: Error?
        var sessionId: UUID?
        var sessionName: String?
        var sessionDate: Date?
        
        ctx.performAndWait {
            let session = AnalysisSessionEntity(context: ctx)
            session.id = UUID()
            session.timestamp = timestamp
            session.createdAt = Date()
            
            // 自动生成名称（格式：YYYY 年 M 月 D 日）
            let generatedName = self.generateSessionName(for: Date(), context: ctx)
            session.customName = generatedName
            session.customDate = Date()
            session.isFavorite = false  // 默认未收藏
            
            session.totalPhotoCount = Int16(totalPhotoCount)
            session.processedCount = Int16(processedCount)
            session.failedCount = Int16(failedCount)
            session.optimalK = Int16(optimalK)
            session.silhouetteScore = silhouetteScore
            session.status = isCompleted ? "completed" : "processing"
            
            // 保存用户输入的感受
            if let userMessage = result.userMessage, !userMessage.isEmpty {
                session.userMessage = userMessage
                print("💾 保存用户感受: \(userMessage)")
            }
            
            // 保存 AI 评价数据
            if let aiEvaluation = result.aiEvaluation {
                print("💾 准备保存 AI 评价数据:")
                print("   - 整体评价: \(aiEvaluation.overallEvaluation != nil ? "有" : "无")")
                print("   - 聚类评价数: \(aiEvaluation.clusterEvaluations.count)")
                print("   - isLoading: \(aiEvaluation.isLoading)")
                print("   - error: \(aiEvaluation.error ?? "无")")
                
                if let evaluationData = try? JSONEncoder().encode(aiEvaluation) {
                    session.aiEvaluationData = evaluationData
                    print("   ✅ AI 评价数据已编码，大小: \(evaluationData.count) bytes")
                } else {
                    print("   ❌ AI 评价数据编码失败")
                }
            } else {
                print("   ⚠️ result.aiEvaluation 为 nil，不保存 AI 评价")
            }
        
        // 保存聚类信息
        var clusterEntities: [ColorClusterEntity] = []
        let converter = ColorSpaceConverter()
        for cluster in clusters {
            let clusterEntity = ColorClusterEntity(context: ctx)
            clusterEntity.id = UUID()
            clusterEntity.clusterIndex = Int16(cluster.index)
            clusterEntity.colorName = cluster.colorName
            clusterEntity.centroidHex = cluster.hex

            // 保存 LAB 值
            let lab = converter.rgbToLab(cluster.centroid)
            clusterEntity.centroidL = Double(lab.x)
            clusterEntity.centroidA = Double(lab.y)
            clusterEntity.centroidB = Double(lab.z)
            
            // 保存 RGB 值（0-1 范围）
            clusterEntity.centroidR = cluster.centroid.x
            clusterEntity.centroidG = cluster.centroid.y
            clusterEntity.centroidB_RGB = cluster.centroid.z

            clusterEntity.sampleCount = Int16(cluster.photoCount)
            let ratio = processedCount > 0 ? Double(cluster.photoCount) / Double(processedCount) : 0
            clusterEntity.sampleRatio = ratio
            clusterEntity.isNeutral = false

            clusterEntities.append(clusterEntity)
        }
        session.mutableSetValue(forKey: "clusters").addObjects(from: clusterEntities)

        // 保存封面照片（第一张照片的 assetIdentifier）
        if let firstPhoto = photoInfos.first {
            session.coverAssetIdentifier = firstPhoto.assetIdentifier
            print("   📷 保存封面照片: \(firstPhoto.assetIdentifier.prefix(8))...")
        }
        
        // 保存照片分析信息
        var photoAnalysisEntities: [PhotoAnalysisEntity] = []
        for (index, photoInfo) in photoInfos.enumerated() {
            let photoAnalysis = PhotoAnalysisEntity(context: ctx)
            photoAnalysis.id = UUID()
            photoAnalysis.assetLocalIdentifier = photoInfo.assetIdentifier
            photoAnalysis.albumIdentifier = photoInfo.albumIdentifier
            photoAnalysis.albumName = photoInfo.albumName
            photoAnalysis.sortOrder = Int16(index)  // 保存排序顺序
            
            // 调试：记录相册信息保存
            if let albumId = photoInfo.albumIdentifier, let albumName = photoInfo.albumName {
                print("   💾 保存相册信息: \(albumName) (ID: \(albumId.prefix(8))...) → 照片 \(photoInfo.assetIdentifier.prefix(8))...")
            }

            if let primaryIndex = photoInfo.primaryClusterIndex {
                photoAnalysis.primaryClusterIndex = Int16(primaryIndex)
                if let cluster = clusters.first(where: { $0.index == primaryIndex }) {
                    photoAnalysis.primaryColorName = cluster.colorName
                }
            }

            // 保存主色信息
            if let dominantColorsData = try? JSONEncoder().encode(photoInfo.dominantColors) {
                photoAnalysis.dominantColors = dominantColorsData
            }
            
            // 保存视觉代表色（5个主色在 LAB 空间的加权平均）
            if let visualColor = photoInfo.visualRepresentativeColor {
                photoAnalysis.visualRepresentativeColorR = visualColor.x
                photoAnalysis.visualRepresentativeColorG = visualColor.y
                photoAnalysis.visualRepresentativeColorB = visualColor.z
            }

            // 保存簇混合向量
            if let mixVectorData = try? JSONEncoder().encode(photoInfo.clusterMix) {
                photoAnalysis.mixVector = mixVectorData
            }

            // 保存 brightnessCDF
            if let cdf = photoInfo.brightnessCDF, !cdf.isEmpty {
                let cdfData = Data(bytes: cdf, count: cdf.count * MemoryLayout<Float>.size)
                photoAnalysis.brightnessCDF = cdfData
            }
            
            // 保存明度中位数和对比度（影调模式聚类用）
            if let median = photoInfo.brightnessMedian {
                photoAnalysis.brightnessMedian = median
            }
            if let contrast = photoInfo.brightnessContrast {
                photoAnalysis.brightnessContrast = contrast
            }
            
            // 保存高级色彩分析（单张照片）
            if let advancedColorAnalysis = photoInfo.advancedColorAnalysis {
                // 保存完整的 AdvancedColorAnalysis 结构（包含所有数据）
                if let analysisData = try? JSONEncoder().encode(advancedColorAnalysis) {
                    photoAnalysis.advancedColorAnalysisData = analysisData
                }
                
                // 保留旧字段用于兼容性和快速查询
                photoAnalysis.warmCoolScore = advancedColorAnalysis.overallScore
                
                // 保存色偏分析数据（新版本：分别保存高光和阴影区域）
                if let colorCast = advancedColorAnalysis.colorCastResult {
                    photoAnalysis.colorCastRMS = colorCast.rms
                    
                    // 高光区域色偏（Optional，当 ratio < 1% 时为 nil）
                    photoAnalysis.colorCastHighlightAMean = colorCast.highlightAMean ?? 0
                    photoAnalysis.colorCastHighlightBMean = colorCast.highlightBMean ?? 0
                    photoAnalysis.colorCastHighlightCast = colorCast.highlightCast ?? 0
                    photoAnalysis.colorCastHighlightHue = colorCast.highlightHueDegrees ?? 0
                    
                    // 阴影区域色偏（Optional，当 ratio < 1% 时为 nil）
                    photoAnalysis.colorCastShadowAMean = colorCast.shadowAMean ?? 0
                    photoAnalysis.colorCastShadowBMean = colorCast.shadowBMean ?? 0
                    photoAnalysis.colorCastShadowCast = colorCast.shadowCast ?? 0
                    photoAnalysis.colorCastShadowHue = colorCast.shadowHueDegrees ?? 0
                    
                    // 兼容性字段（平均值）
                    photoAnalysis.colorCastAMean = colorCast.aMean
                    photoAnalysis.colorCastBMean = colorCast.bMean
                    photoAnalysis.colorCastStrength = colorCast.cast
                    photoAnalysis.colorCastHue = colorCast.hueAngleDegrees
                }
            }

            // 保存 Vision 信息
            if let visionInfo = photoInfo.visionInfo {
                if let visionData = try? JSONEncoder().encode(visionInfo) {
                    photoAnalysis.visionInfo = visionData
                }
            }

            // 保存图像特征
            if let imageFeature = photoInfo.imageFeature {
                if let featureData = try? JSONEncoder().encode(imageFeature) {
                    photoAnalysis.imageFeature = featureData
                }
            }
            
            // 保存照片元数据
            if let metadata = photoInfo.metadata {
                let metadataEntity = PhotoMetadataEntity(context: ctx)
                metadataEntity.id = UUID()
                metadataEntity.assetLocalIdentifier = photoInfo.assetIdentifier
                metadataEntity.captureDate = metadata.captureDate
                metadataEntity.aperture = metadata.aperture ?? 0
                metadataEntity.shutterSpeed = metadata.shutterSpeed
                metadataEntity.iso = Int32(metadata.iso ?? 0)
                metadataEntity.focalLength = metadata.focalLength ?? 0
                metadataEntity.cameraMake = metadata.cameraMake
                metadataEntity.cameraModel = metadata.cameraModel
                metadataEntity.lensModel = metadata.lensModel
                
                if photoAnalysis.entity.relationshipsByName["metadata"]?.isToMany == true {
                    // Relationship configured as to-many at runtime (safety for older model versions)
                    let metadataSet = photoAnalysis.mutableSetValue(forKey: "metadata")
                    metadataSet.removeAllObjects()
                    metadataSet.add(metadataEntity)
                } else {
                    photoAnalysis.metadata = metadataEntity
                }
                
                if metadataEntity.entity.relationshipsByName["photoAnalysis"]?.isToMany == true {
                    let analysisSet = metadataEntity.mutableSetValue(forKey: "photoAnalysis")
                    analysisSet.removeAllObjects()
                    analysisSet.add(photoAnalysis)
                } else {
                    metadataEntity.photoAnalysis = photoAnalysis
                }
            }

            photoAnalysis.confidence = 1.0
            photoAnalysis.deltaEToCentroid = 0.0

            photoAnalysisEntities.append(photoAnalysis)
        }
        session.mutableSetValue(forKey: "photoAnalyses").addObjects(from: photoAnalysisEntities)
        
        // 保存作品集特征
        if let collectionFeature = result.collectionFeature {
            let collectionEntity = CollectionFeatureEntity(context: ctx)
            collectionEntity.id = UUID()
            collectionEntity.meanWarmCoolScore = collectionFeature.meanCoolWarmScore
            
            // 保存完整的 CollectionFeature 数据
            if let featureData = try? JSONEncoder().encode(collectionFeature) {
                collectionEntity.collectionFeatureData = featureData
            }
            
            session.setValue(collectionEntity, forKey: "collectionFeature")
        }
        
            // 保存到 Core Data
            do {
                try ctx.save()
                savedSession = session
                // 立即提取值，避免跨上下文访问问题
                sessionId = session.id
                sessionName = session.customName
                sessionDate = session.customDate
                print("✅ 已保存分析会话到 Core Data")
                print("   - 提取的 sessionId: \(sessionId?.uuidString ?? "nil")")
                print("   - 提取的名称: \(sessionName ?? "nil")")
            } catch {
                saveError = error
            }
        }
        
        if let error = saveError {
            throw error
        }
        
        // 返回提取的值，避免跨上下文访问问题
        return (id: sessionId, name: sessionName, date: sessionDate)
    }
    
    /// 获取所有分析会话（按时间倒序）
    func fetchAllSessions() -> [AnalysisSessionEntity] {
        let request = AnalysisSessionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching sessions: \(error)")
            return []
        }
    }
    
    /// 获取最近的N个会话
    func fetchRecentSessions(limit: Int = 10) -> [AnalysisSessionEntity] {
        let request = AnalysisSessionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching recent sessions: \(error)")
            return []
        }
    }
    
    /// 根据ID获取会话
    func fetchSession(id: UUID) -> AnalysisSessionEntity? {
        let request = AnalysisSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Error fetching session: \(error)")
            return nil
        }
    }
    
    /// 删除会话
    func deleteSession(_ session: AnalysisSessionEntity) throws {
        viewContext.delete(session)
        try viewContext.save()
    }
    
    /// 清除所有分析会话（同时清除关联的 PhotoAnalysisEntity 和聚类缓存）
    func clearAllSessions() throws {
        // 1. 先删除所有 PhotoAnalysisEntity
        let photoRequest: NSFetchRequest<NSFetchRequestResult> = PhotoAnalysisEntity.fetchRequest()
        let photoDeleteRequest = NSBatchDeleteRequest(fetchRequest: photoRequest)
        photoDeleteRequest.resultType = .resultTypeObjectIDs
        
        let photoResult = try viewContext.execute(photoDeleteRequest) as? NSBatchDeleteResult
        let photoObjectIDArray = photoResult?.result as? [NSManagedObjectID] ?? []
        let photoChanges = [NSDeletedObjectsKey: photoObjectIDArray]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: photoChanges, into: [viewContext])
        
        print("🗑️ 已清除 \(photoObjectIDArray.count) 个照片分析记录")
        
        // 2. 删除所有 AnalysisSessionEntity
        let sessionRequest: NSFetchRequest<NSFetchRequestResult> = AnalysisSessionEntity.fetchRequest()
        let sessionDeleteRequest = NSBatchDeleteRequest(fetchRequest: sessionRequest)
        sessionDeleteRequest.resultType = .resultTypeObjectIDs
        
        let sessionResult = try viewContext.execute(sessionDeleteRequest) as? NSBatchDeleteResult
        let sessionObjectIDArray = sessionResult?.result as? [NSManagedObjectID] ?? []
        let sessionChanges = [NSDeletedObjectsKey: sessionObjectIDArray]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: sessionChanges, into: [viewContext])
        
        print("🗑️ 已清除 \(sessionObjectIDArray.count) 个分析会话")
        
        // 3. 删除所有显影聚类缓存
        let cacheRequest: NSFetchRequest<NSFetchRequestResult> = DevelopmentClusterCacheEntity.fetchRequest()
        let cacheDeleteRequest = NSBatchDeleteRequest(fetchRequest: cacheRequest)
        cacheDeleteRequest.resultType = .resultTypeObjectIDs
        
        let cacheResult = try viewContext.execute(cacheDeleteRequest) as? NSBatchDeleteResult
        let cacheObjectIDArray = cacheResult?.result as? [NSManagedObjectID] ?? []
        let cacheChanges = [NSDeletedObjectsKey: cacheObjectIDArray]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: cacheChanges, into: [viewContext])
        
        print("🗑️ 已清除 \(cacheObjectIDArray.count) 个显影聚类缓存")
    }
    
    // MARK: - Phase 3: 数据清理
    
    /// 获取近 7 天内的所有会话
    func fetchSessionsWithinDays(_ days: Int = 7) -> [AnalysisSessionEntity] {
        let request = AnalysisSessionEntity.fetchRequest()
        let calendar = Calendar.current
        let daysAgo = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        request.predicate = NSPredicate(format: "createdAt >= %@", daysAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ 获取近 \(days) 天会话失败: \(error)")
            return []
        }
    }
    
    
    /// 获取数据统计信息
    func getDataStatistics() -> (total: Int, favorites: Int, within7Days: Int) {
        let request = AnalysisSessionEntity.fetchRequest()
        
        do {
            let allSessions = try viewContext.fetch(request)
            let total = allSessions.count
            let favorites = allSessions.filter { $0.isFavorite }.count
            
            let calendar = Calendar.current
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let within7Days = allSessions.filter { ($0.createdAt ?? Date()) >= sevenDaysAgo }.count
            
            return (total, favorites, within7Days)
        } catch {
            print("❌ 获取统计信息失败: \(error)")
            return (0, 0, 0)
        }
    }
    
    // MARK: - Phase 3: 清空功能
    
    /// 清空所有 Vision 标签数据（从 Core Data 删除）
    /// - Returns: 删除的标签数量
    @discardableResult
    func clearAllVisionTags() -> Int {
        let request = VisionTagEntity.fetchRequest()
        
        do {
            let tags = try viewContext.fetch(request)
            let count = tags.count
            
            if count > 0 {
                print("🗑️ 开始清空所有 Vision 标签数据...")
                print("   找到 \(count) 个标签需要删除")
                
                for tag in tags {
                    viewContext.delete(tag)
                }
                
                try viewContext.save()
                print("✅ 已删除 \(count) 个 Vision 标签")
            } else {
                print("✅ 没有 Vision 标签数据需要清空")
            }
            
            return count
        } catch {
            print("❌ 清空 Vision 标签数据失败: \(error)")
            return 0
        }
    }
    
    // MARK: - Session Naming Helpers
    
    /// 生成分析会话名称（格式：YYYY.MM.dd）
    /// 如果同一天有多次分析，自动添加 (1), (2) 等后缀
    /// 示例：2025.11.12, 2025.11.12(1), 2025.11.12(2)
    /// - Parameters:
    ///   - date: 日期
    ///   - context: Core Data 上下文
    /// - Returns: 生成的名称
    private func generateSessionName(for date: Date, context: NSManagedObjectContext) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        let baseName = formatter.string(from: date)
        
        // 查询同一天是否已有分析会话
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<AnalysisSessionEntity> = AnalysisSessionEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "customDate >= %@ AND customDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "customDate", ascending: true)]
        
        do {
            let existingSessions = try context.fetch(request)
            
            // 如果没有同名的，直接返回基础名称
            if existingSessions.isEmpty {
                return baseName
            }
            
            // 找出已使用的后缀数字
            // 0 表示基础名称（无后缀），1 表示 (1)，2 表示 (2)，以此类推
            var usedNumbers: Set<Int> = []
            for session in existingSessions {
                if let name = session.customName {
                    if name == baseName {
                        usedNumbers.insert(0)  // 基础名称对应 0
                    } else if name.hasPrefix(baseName + "(") && name.hasSuffix(")") {
                        let numberPart = name.dropFirst(baseName.count + 1).dropLast()
                        if let number = Int(numberPart) {
                            usedNumbers.insert(number)
                        }
                    }
                }
            }
            
            // 找到第一个未使用的数字（从 0 开始）
            var nextNumber = 0
            while usedNumbers.contains(nextNumber) {
                nextNumber += 1
            }
            
            // 0 对应基础名称，其他对应带后缀的名称
            if nextNumber == 0 {
                return baseName
            } else {
            return "\(baseName)(\(nextNumber))"
            }
        } catch {
            print("❌ 查询已有会话失败: \(error)")
            return baseName
        }
    }
    
    /// 更新分析会话的收藏状态和自定义信息
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - isFavorite: 是否收藏
    ///   - customName: 自定义名称（可选）
    ///   - customDate: 自定义日期（可选）
    /// 更新会话的 AI 评价数据
    func updateAIEvaluation(sessionId: UUID, evaluation: ColorEvaluation) async throws {
        let context = container.newBackgroundContext()
        
        try await context.perform {
            let request: NSFetchRequest<AnalysisSessionEntity> = AnalysisSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
            request.fetchLimit = 1
            
            guard let session = try context.fetch(request).first else {
                throw NSError(domain: "CoreDataManager", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Session not found"
                ])
            }
            
            // 编码并保存 AI 评价
            if let evaluationData = try? JSONEncoder().encode(evaluation) {
                session.aiEvaluationData = evaluationData
                print("💾 更新 AI 评价数据: \(evaluationData.count) bytes")
            }
            
            try context.save()
        }
    }
    
    func updateSessionFavoriteStatus(
        sessionId: UUID,
        isFavorite: Bool,
        customName: String? = nil,
        customDate: Date? = nil
    ) throws {
        print("🔧 CoreDataManager.updateSessionFavoriteStatus 被调用")
        print("   - sessionId: \(sessionId)")
        print("   - isFavorite: \(isFavorite)")
        
        let context = viewContext
        
        let request: NSFetchRequest<AnalysisSessionEntity> = AnalysisSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        print("   - 找到 \(results.count) 个匹配的实体")
        
        guard let session = results.first else {
            print("❌ 未找到 session")
            throw NSError(domain: "CoreDataManager", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Session not found"
            ])
        }
        
        print("   - 当前 isFavorite: \(session.isFavorite)")
        session.isFavorite = isFavorite
        print("   - 更新后 isFavorite: \(session.isFavorite)")
        
        if let name = customName {
            session.customName = name
        }
        
        if let date = customDate {
            session.customDate = date
        }
        
        try context.save()
        print("✅ 已保存到 Core Data: isFavorite=\(isFavorite)")
    }
    
    // MARK: - 显影页聚类缓存管理
    
    /// 显影页聚类缓存数据结构
    struct DevelopmentClusterCache: Codable {
        let mode: String  // "tone", "shadow", "comprehensive"
        let photoCount: Int
        let lastUpdated: Date
        let clusters: [CachedCluster]
        
        struct CachedCluster: Codable {
            let id: UUID
            // 色调/综合模式使用
            let centroidL: Float?
            let centroidA: Float?
            let centroidB: Float?
            let centroidR: Float?
            let centroidG: Float?
            let centroidB_RGB: Float?
            // 影调模式使用
            let centroidBrightnessMedian: Float?
            let centroidContrast: Float?
            // 通用
            let photoCount: Int
            let photoIdentifiers: [String]
        }
    }
    
    /// 保存显影页聚类缓存
    func saveDevelopmentClusterCache(_ cache: DevelopmentClusterCache) async throws {
        let context = container.newBackgroundContext()
        
        try await context.perform {
            // 查找是否已存在该模式的缓存
            let request: NSFetchRequest<DevelopmentClusterCacheEntity> = DevelopmentClusterCacheEntity.fetchRequest()
            request.predicate = NSPredicate(format: "mode == %@", cache.mode)
            request.fetchLimit = 1
            
            let entity: DevelopmentClusterCacheEntity
            if let existing = try context.fetch(request).first {
                entity = existing
                print("📊 更新显影缓存: \(cache.mode)")
            } else {
                entity = DevelopmentClusterCacheEntity(context: context)
                entity.id = UUID()
                print("📊 创建显影缓存: \(cache.mode)")
            }
            
            entity.mode = cache.mode
            entity.photoCount = Int32(cache.photoCount)
            entity.lastUpdated = cache.lastUpdated
            
            // 编码聚类数据
            if let clustersData = try? JSONEncoder().encode(cache.clusters) {
                entity.clustersData = clustersData
            }
            
            try context.save()
            print("✅ 显影缓存已保存: \(cache.mode), 照片数: \(cache.photoCount), 聚类数: \(cache.clusters.count)")
        }
    }
    
    /// 加载显影页聚类缓存
    func loadDevelopmentClusterCache(mode: String) async -> DevelopmentClusterCache? {
        let context = container.newBackgroundContext()
        
        return await context.perform {
            let request: NSFetchRequest<DevelopmentClusterCacheEntity> = DevelopmentClusterCacheEntity.fetchRequest()
            request.predicate = NSPredicate(format: "mode == %@", mode)
            request.fetchLimit = 1
            
            do {
                guard let entity = try context.fetch(request).first,
                      let clustersData = entity.clustersData,
                      let clusters = try? JSONDecoder().decode([DevelopmentClusterCache.CachedCluster].self, from: clustersData) else {
                    print("📊 显影缓存不存在: \(mode)")
                    return nil
                }
                
                let cache = DevelopmentClusterCache(
                    mode: entity.mode ?? mode,
                    photoCount: Int(entity.photoCount),
                    lastUpdated: entity.lastUpdated ?? Date.distantPast,
                    clusters: clusters
                )
                
                print("✅ 加载显影缓存: \(mode), 照片数: \(cache.photoCount), 聚类数: \(clusters.count)")
                return cache
            } catch {
                print("❌ 加载显影缓存失败: \(error)")
                return nil
            }
        }
    }
    
    /// 获取当前照片总数（用于缓存失效检测）
    func fetchTotalPhotoCount() async -> Int {
        let context = container.newBackgroundContext()
        
        return await context.perform {
            let request: NSFetchRequest<PhotoAnalysisEntity> = PhotoAnalysisEntity.fetchRequest()
            do {
                return try context.count(for: request)
            } catch {
                print("❌ 获取照片数量失败: \(error)")
                return 0
            }
        }
    }
    
    /// 获取收藏照片集中的照片数量（用于缓存失效检测）
    /// - Parameter favoriteAlbumIds: 收藏的相册 ID 集合
    func fetchFavoritePhotoCount(favoriteAlbumIds: Set<String>) async -> Int {
        guard !favoriteAlbumIds.isEmpty else { return 0 }
        
        let context = container.newBackgroundContext()
        
        return await context.perform {
            let request: NSFetchRequest<PhotoAnalysisEntity> = PhotoAnalysisEntity.fetchRequest()
            request.predicate = NSPredicate(format: "albumIdentifier IN %@", favoriteAlbumIds)
            do {
                return try context.count(for: request)
            } catch {
                print("❌ 获取收藏照片数量失败: \(error)")
                return 0
            }
        }
    }
    
    /// 删除指定模式的显影缓存
    func deleteDevelopmentClusterCache(mode: String) async throws {
        let context = container.newBackgroundContext()
        
        try await context.perform {
            let request: NSFetchRequest<DevelopmentClusterCacheEntity> = DevelopmentClusterCacheEntity.fetchRequest()
            request.predicate = NSPredicate(format: "mode == %@", mode)
            
            let results = try context.fetch(request)
            for entity in results {
                context.delete(entity)
            }
            
            try context.save()
            print("🗑️ 已删除显影缓存: \(mode)")
        }
    }
}
