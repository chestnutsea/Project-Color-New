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
    func saveAnalysisSession(
        from result: AnalysisResult,
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

            if let primaryIndex = photoInfo.primaryClusterIndex {
                photoAnalysis.primaryClusterIndex = Int16(primaryIndex)
                if let cluster = clusters.first(where: { $0.index == primaryIndex }) {
                    photoAnalysis.primaryColorName = cluster.colorName
                }
            }

            if let dominantColorsData = try? JSONEncoder().encode(photoInfo.dominantColors) {
                photoAnalysis.dominantColors = dominantColorsData
            }

            if let mixVectorData = try? JSONEncoder().encode(photoInfo.clusterMix) {
                photoAnalysis.mixVector = mixVectorData
            }

            photoAnalysis.confidence = 1.0
            photoAnalysis.deltaEToCentroid = 0.0

            photoAnalysisEntities.append(photoAnalysis)
        }
        session.mutableSetValue(forKey: "photoAnalyses").addObjects(from: photoAnalysisEntities)
        
            do {
                try ctx.save()
                savedSession = session
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
}

