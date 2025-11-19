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
    ///   - isPersonalWork: 是否为"我的作品"（true=保存，false=不保存）
    ///   - context: 可选的上下文
    /// - Returns: 保存的会话实体（如果 isPersonalWork=false 则返回临时实体）
    func saveAnalysisSession(
        from result: AnalysisResult,
        isPersonalWork: Bool,
        context: NSManagedObjectContext? = nil
    ) throws -> AnalysisSessionEntity {
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
        
        ctx.performAndWait {
            let session = AnalysisSessionEntity(context: ctx)
            session.id = UUID()
            session.timestamp = timestamp
            session.createdAt = Date()  // 新增：记录创建时间
            session.isPersonalWork = isPersonalWork  // 新增：标记是否为个人作品
            session.totalPhotoCount = Int16(totalPhotoCount)
            session.processedCount = Int16(processedCount)
            session.failedCount = Int16(failedCount)
            session.optimalK = Int16(optimalK)
            session.silhouetteScore = silhouetteScore
            session.status = isCompleted ? "completed" : "processing"
        
        // 保存聚类信息
        var clusterEntities: [ColorClusterEntity] = []
        let converter = ColorSpaceConverter()
        for cluster in clusters {
            let clusterEntity = ColorClusterEntity(context: ctx)
            clusterEntity.id = UUID()
            clusterEntity.clusterIndex = Int16(cluster.index)
            clusterEntity.colorName = cluster.colorName
            clusterEntity.centroidHex = cluster.hex

            let lab = converter.rgbToLab(cluster.centroid)
            clusterEntity.centroidL = Double(lab.x)
            clusterEntity.centroidA = Double(lab.y)
            clusterEntity.centroidB = Double(lab.z)

            clusterEntity.sampleCount = Int16(cluster.photoCount)
            let ratio = processedCount > 0 ? Double(cluster.photoCount) / Double(processedCount) : 0
            clusterEntity.sampleRatio = ratio
            clusterEntity.isNeutral = false

            clusterEntities.append(clusterEntity)
        }
        session.mutableSetValue(forKey: "clusters").addObjects(from: clusterEntities)

        // 保存照片分析信息
        var photoAnalysisEntities: [PhotoAnalysisEntity] = []
        for photoInfo in photoInfos {
            let photoAnalysis = PhotoAnalysisEntity(context: ctx)
            photoAnalysis.id = UUID()
            photoAnalysis.assetLocalIdentifier = photoInfo.assetIdentifier
            photoAnalysis.albumIdentifier = photoInfo.albumIdentifier
            photoAnalysis.albumName = photoInfo.albumName
            
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

            // 保存簇混合向量
            if let mixVectorData = try? JSONEncoder().encode(photoInfo.clusterMix) {
                photoAnalysis.mixVector = mixVectorData
            }

            // 保存冷暖评分（单张照片）
            if let warmCoolScore = photoInfo.warmCoolScore {
                photoAnalysis.warmCoolScore = warmCoolScore.overallScore
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
                metadataEntity.latitude = metadata.latitude ?? 0
                metadataEntity.longitude = metadata.longitude ?? 0
                metadataEntity.locationName = metadata.locationName
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
        
            // 保存到 Core Data（无论是"我的作品"还是"其他图像"）
            do {
                try ctx.save()
                savedSession = session
                if isPersonalWork {
                    print("✅ 我的作品模式：已保存到 Core Data（永久保存）")
                } else {
                    print("✅ 其他图像模式：已保存到 Core Data（7天后自动删除）")
                }
            } catch {
                saveError = error
            }
        }
        
        if let error = saveError {
            throw error
        }
        
        return savedSession
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
    
    /// 清理超过 7 天的"其他图像"数据
    /// - Returns: 删除的会话数量
    @discardableResult
    func cleanupOldOtherImageSessions(olderThanDays days: Int = 7) -> Int {
        let request = AnalysisSessionEntity.fetchRequest()
        let calendar = Calendar.current
        let daysAgo = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // 查询条件：超过 7 天 且 不是"我的作品"
        request.predicate = NSPredicate(
            format: "createdAt < %@ AND isPersonalWork == NO",
            daysAgo as NSDate
        )
        
        do {
            let oldSessions = try viewContext.fetch(request)
            let count = oldSessions.count
            
            if count > 0 {
                print("🗑️ 开始清理超过 \(days) 天的\"其他图像\"数据...")
                print("   找到 \(count) 个会话需要删除")
                
                for session in oldSessions {
                    viewContext.delete(session)
                }
                
                try viewContext.save()
                print("✅ 已删除 \(count) 个旧会话")
            } else {
                print("✅ 没有需要清理的旧数据")
            }
            
            return count
        } catch {
            print("❌ 清理旧数据失败: \(error)")
            return 0
        }
    }
    
    /// 获取数据统计信息
    func getDataStatistics() -> (total: Int, personalWork: Int, otherImage: Int, within7Days: Int) {
        let request = AnalysisSessionEntity.fetchRequest()
        
        do {
            let allSessions = try viewContext.fetch(request)
            let total = allSessions.count
            let personalWork = allSessions.filter { $0.isPersonalWork }.count
            let otherImage = allSessions.filter { !$0.isPersonalWork }.count
            
            let calendar = Calendar.current
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let within7Days = allSessions.filter { ($0.createdAt ?? Date()) >= sevenDaysAgo }.count
            
            return (total, personalWork, otherImage, within7Days)
        } catch {
            print("❌ 获取统计信息失败: \(error)")
            return (0, 0, 0, 0)
        }
    }
    
    // MARK: - Phase 3: 清空功能
    
    /// 清空所有"其他图像"数据（从 Core Data 删除）
    /// - Returns: 删除的会话数量
    @discardableResult
    func clearAllOtherImageSessions() -> Int {
        let request = AnalysisSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isPersonalWork == NO")
        
        do {
            let sessions = try viewContext.fetch(request)
            let count = sessions.count
            
            if count > 0 {
                print("🗑️ 开始清空所有\"其他图像\"数据...")
                print("   找到 \(count) 个会话需要删除")
                
                for session in sessions {
                    viewContext.delete(session)
                }
                
                try viewContext.save()
                print("✅ 已删除 \(count) 个\"其他图像\"会话")
            } else {
                print("✅ 没有\"其他图像\"数据需要清空")
            }
            
            return count
        } catch {
            print("❌ 清空\"其他图像\"数据失败: \(error)")
            return 0
        }
    }
    
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
}
